/// Shared migration engine for generated database modules.
///
/// Generated `migration.gleam` files supply only the entity-specific declarative
/// data (SQL strings, column specs, index specs); this module owns the full
/// reconciliation engine that is identical for every entity.
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sql/pragma_assert.{type TableInfoRow} as sqlite_pragma_assert
import sql/sqlite_ident
import sqlight

// ── Public types ─────────────────────────────────────────────────────────────

/// Shared column descriptor. Replaces the per-entity private `XxxCol` type.
pub type ColumnSpec {
  ColumnSpec(name: String, type_: String, notnull: Int, pk: Int)
}

/// Per-index descriptor for one table.
pub type IndexSpec {
  IndexSpec(name: String, create_sql: String, expected_info_tsv: String)
}

/// All entity-specific data a migration needs to supply for one table.
pub type TableSpec {
  TableSpec(
    table: String,
    columns: List(ColumnSpec),
    create_table_sql: String,
    indexes: List(IndexSpec),
    expected_table_info: String,
    /// Full `pragma index_list` TSV snapshot for this table (all indexes).
    expected_index_list: String,
  )
}

// ── Internal helpers ──────────────────────────────────────────────────────────

fn pragma_index_name_origin_rows(
  conn: sqlight.Connection,
  table: String,
) -> Result(List(#(String, String)), sqlight.Error) {
  sqlight.query(
    "pragma index_list(" <> table <> ")",
    on: conn,
    with: [],
    expecting: {
      use name <- decode.field(1, decode.string)
      use origin <- decode.field(3, decode.string)
      decode.success(#(name, origin))
    },
  )
}

fn col_matches(want: ColumnSpec, got: TableInfoRow) -> Bool {
  want.name == got.name
  && string.uppercase(got.type_) == want.type_
  && want.notnull == got.notnull
  && want.pk == got.pk
  && case want.notnull {
    0 -> got.dflt == None || got.dflt == Some("")
    _ -> True
  }
}

fn first_surplus_column(
  rows: List(TableInfoRow),
  wanted: List(ColumnSpec),
) -> Option(String) {
  case list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) }) {
    Ok(r) -> Some(r.name)
    Error(Nil) -> None
  }
}

fn first_mismatched_column_name(
  rows: List(TableInfoRow),
  wanted: List(ColumnSpec),
) -> Option(String) {
  case
    list.find_map(wanted, fn(w) {
      case list.find(rows, fn(r) { r.name == w.name }) {
        Error(Nil) -> Error(Nil)
        Ok(row) ->
          case col_matches(w, row) {
            True -> Error(Nil)
            False -> Ok(w.name)
          }
      }
    })
  {
    Ok(name) -> Some(name)
    Error(Nil) -> None
  }
}

fn first_missing_column(
  rows: List(TableInfoRow),
  wanted: List(ColumnSpec),
) -> Option(ColumnSpec) {
  case list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) }) {
    Ok(w) -> Some(w)
    Error(Nil) -> None
  }
}

fn alter_add_column_sql(table: String, w: ColumnSpec) -> String {
  let fragment = case w.name {
    "id" -> "integer primary key autoincrement not null"
    "deleted_at" -> "integer"
    _ ->
      case string.uppercase(w.type_) {
        "INTEGER" -> "integer"
        "TEXT" -> "text"
        "REAL" -> "real"
        _ -> "text"
      }
      <> case w.notnull {
        1 -> " not null"
        _ -> ""
      }
  }
  "alter table "
  <> sqlite_ident.quote(table)
  <> " add column "
  <> sqlite_ident.quote(w.name)
  <> " "
  <> fragment
  <> ";"
}

fn apply_one_column_fix(
  conn: sqlight.Connection,
  table: String,
  rows: List(TableInfoRow),
  wanted: List(ColumnSpec),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column(rows, wanted) {
    Some(name) ->
      sqlight.exec(
        "alter table "
          <> sqlite_ident.quote(table)
          <> " drop column "
          <> sqlite_ident.quote(name)
          <> ";",
        conn,
      )
    None ->
      case first_mismatched_column_name(rows, wanted) {
        Some(name) ->
          sqlight.exec(
            "alter table "
              <> sqlite_ident.quote(table)
              <> " drop column "
              <> sqlite_ident.quote(name)
              <> ";",
            conn,
          )
        None ->
          case first_missing_column(rows, wanted) {
            Some(w) -> sqlight.exec(alter_add_column_sql(table, w), conn)
            None -> panic as "swil/runtime/migration: no column fix applies"
          }
      }
  }
}

fn reconcile_columns_loop(
  conn: sqlight.Connection,
  table: String,
  wanted: List(ColumnSpec),
  iter: Int,
) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
    True ->
      panic as "swil/runtime/migration: column reconcile did not converge"
    False -> {
      use rows <- result.try(sqlite_pragma_assert.table_info_rows(conn, table))
      case
        list.length(rows) == list.length(wanted)
        && list.all(wanted, fn(w) {
          case list.find(rows, fn(r) { r.name == w.name }) {
            Ok(row) -> col_matches(w, row)
            Error(Nil) -> False
          }
        })
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(apply_one_column_fix(conn, table, rows, wanted))
          reconcile_columns_loop(conn, table, wanted, iter + 1)
        }
      }
    }
  }
}

fn drop_surplus_user_indexes(
  conn: sqlight.Connection,
  table: String,
  keep_names: List(String),
) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, table))
  list.try_each(rows, fn(pair) {
    let #(name, origin) = pair
    case origin == "c" && !list.contains(keep_names, name) {
      True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
      False -> Ok(Nil)
    }
  })
}

fn drop_all_indexes(
  conn: sqlight.Connection,
  indexes: List(IndexSpec),
) -> Result(Nil, sqlight.Error) {
  list.try_each(indexes, fn(idx) {
    sqlight.exec("drop index if exists " <> idx.name <> ";", conn)
  })
}

fn ensure_table(
  conn: sqlight.Connection,
  spec: TableSpec,
) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
  case list.contains(tables, spec.table) {
    False -> sqlight.exec(spec.create_table_sql, conn)
    True -> {
      use _ <- result.try(drop_all_indexes(conn, spec.indexes))
      reconcile_columns_loop(conn, spec.table, spec.columns, 0)
    }
  }
}

fn ensure_indexes(
  conn: sqlight.Connection,
  spec: TableSpec,
) -> Result(Nil, sqlight.Error) {
  let index_names = list.map(spec.indexes, fn(i) { i.name })
  use _ <- result.try(drop_surplus_user_indexes(conn, spec.table, index_names))
  let all_match = case sqlite_pragma_assert.index_list_tsv(conn, spec.table) {
    Error(_) -> False
    Ok(list_tsv) ->
      list_tsv == spec.expected_index_list
      && list.all(spec.indexes, fn(idx) {
        case sqlite_pragma_assert.index_info_tsv(conn, idx.name) {
          Ok(info_tsv) -> info_tsv == idx.expected_info_tsv
          Error(_) -> False
        }
      })
  }
  case all_match {
    True -> Ok(Nil)
    False -> {
      use _ <- result.try(drop_all_indexes(conn, spec.indexes))
      list.try_each(spec.indexes, fn(idx) {
        sqlight.exec(idx.create_sql, conn)
      })
    }
  }
}

// ── Public entry point ────────────────────────────────────────────────────────

/// Apply all `specs` in order:
/// 1. Drop user tables not listed in any spec.
/// 2. For each spec: ensure the table exists and its columns match.
/// 3. For each spec: ensure its indexes match.
/// 4. Assert final pragma snapshots for every (table, index) pair.
pub fn run(
  conn: sqlight.Connection,
  specs: List(TableSpec),
) -> Result(Nil, sqlight.Error) {
  let keep = list.map(specs, fn(s) { s.table })
  use _ <- result.try(
    sqlite_pragma_assert.drop_user_tables_except_any(conn, keep),
  )
  use _ <- result.try(list.try_each(specs, fn(spec) {
    use _ <- result.try(ensure_table(conn, spec))
    ensure_indexes(conn, spec)
  }))
  list.each(specs, fn(spec) {
    list.each(spec.indexes, fn(idx) {
      sqlite_pragma_assert.assert_pragma_snapshot(
        conn,
        keep,
        spec.table,
        spec.expected_table_info,
        spec.expected_index_list,
        idx.name,
        idx.expected_info_tsv,
      )
    })
  })
  Ok(Nil)
}
