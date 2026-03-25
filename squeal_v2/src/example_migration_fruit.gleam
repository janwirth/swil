//// Blueprint for a generated `migrate`: introspect user tables and `fruit` columns /
//// indexes, then move to the desired state using `ALTER TABLE` only (add / drop column),
//// never `DROP TABLE` / `CREATE TABLE` for shape fixes once `fruit` exists.
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sqlite_pragma_assert.{type TableInfoRow}
import sqlight

const create_fruit_table_sql = "create table fruit (
  id integer primary key autoincrement not null,
  name text not null,
  color text not null,
  price real not null,
  quantity integer not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer
);"

const create_fruit_by_name_index_sql =
  "create unique index fruit_by_name on fruit(name);"

const expected_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	1	NULL	0
2	color	TEXT	1	NULL	0
3	price	REAL	1	NULL	0
4	quantity	INTEGER	1	NULL	0
5	created_at	INTEGER	1	NULL	0
6	updated_at	INTEGER	1	NULL	0
7	deleted_at	INTEGER	0	NULL	0"

const expected_index_list = "seq	name	unique	origin	partial
0	fruit_by_name	1	c	0"

const expected_index_info = "seqno	cid	name
0	1	name"

type FruitCol {
  FruitCol(name: String, type_: String, notnull: Int, pk: Int)
}

const fruit_columns_wanted = [
  FruitCol("id", "INTEGER", 1, 1),
  FruitCol("name", "TEXT", 1, 0),
  FruitCol("color", "TEXT", 1, 0),
  FruitCol("price", "REAL", 1, 0),
  FruitCol("quantity", "INTEGER", 1, 0),
  FruitCol("created_at", "INTEGER", 1, 0),
  FruitCol("updated_at", "INTEGER", 1, 0),
  FruitCol("deleted_at", "INTEGER", 0, 0),
]

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

fn drop_surplus_user_indexes_on_fruit(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "fruit"))
  list.try_each(rows, fn(pair) {
    let #(name, origin) = pair
    case origin == "c" && name != "fruit_by_name" {
      True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
      False -> Ok(Nil)
    }
  })
}

fn type_matches(expected: String, got: String) -> Bool {
  string.uppercase(got) == expected
}

fn fruit_row_matches(want: FruitCol, got: TableInfoRow) -> Bool {
  want.name == got.name
  && type_matches(want.type_, got.type_)
  && want.notnull == got.notnull
  && want.pk == got.pk
  && case want.notnull {
    0 -> got.dflt == None || got.dflt == Some("")
    _ -> True
  }
}

fn first_surplus_column(
  rows: List(TableInfoRow),
  wanted: List(FruitCol),
) -> Option(String) {
  case
    list.find(rows, fn(r) {
      !list.any(wanted, fn(w) { w.name == r.name })
    })
  {
    Ok(r) -> Some(r.name)
    Error(Nil) -> None
  }
}

fn first_mismatched_column_name(
  rows: List(TableInfoRow),
  wanted: List(FruitCol),
) -> Option(String) {
  case
    list.find_map(wanted, fn(w) {
      case list.find(rows, fn(r) { r.name == w.name }) {
        Error(Nil) -> Error(Nil)
        Ok(row) ->
          case fruit_row_matches(w, row) {
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
  wanted: List(FruitCol),
) -> Option(FruitCol) {
  case
    list.find(wanted, fn(w) {
      !list.any(rows, fn(r) { r.name == w.name })
    })
  {
    Ok(w) -> Some(w)
    Error(Nil) -> None
  }
}

fn alter_add_fruit_column_sql(w: FruitCol) -> String {
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
  "alter table fruit add column " <> w.name <> " " <> fragment <> ";"
}

fn apply_one_fruit_column_fix(
  conn: sqlight.Connection,
  rows: List(TableInfoRow),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column(rows, fruit_columns_wanted) {
    Some(name) ->
      sqlight.exec("alter table fruit drop column " <> name <> ";", conn)
    None ->
      case first_mismatched_column_name(rows, fruit_columns_wanted) {
        Some(name) ->
          sqlight.exec("alter table fruit drop column " <> name <> ";", conn)
        None ->
          case first_missing_column(rows, fruit_columns_wanted) {
            Some(w) -> sqlight.exec(alter_add_fruit_column_sql(w), conn)
            None -> panic as "example_migration_fruit: no column fix applies"
          }
      }
  }
}

fn reconcile_fruit_columns_loop(
  conn: sqlight.Connection,
  iter: Int,
) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
    True ->
      panic as "example_migration_fruit: column reconcile did not converge"
    False -> {
      use rows <- result.try(sqlite_pragma_assert.table_info_rows(conn, "fruit"))
      case
        list.length(rows) == list.length(fruit_columns_wanted)
        && list.all(fruit_columns_wanted, fn(w) {
          case list.find(rows, fn(r) { r.name == w.name }) {
            Ok(row) -> fruit_row_matches(w, row)
            Error(Nil) -> False
          }
        })
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(apply_one_fruit_column_fix(conn, rows))
          reconcile_fruit_columns_loop(conn, iter + 1)
        }
      }
    }
  }
}

fn ensure_fruit_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
  case list.contains(tables, "fruit") {
    False -> sqlight.exec(create_fruit_table_sql, conn)
    True -> reconcile_fruit_columns_loop(conn, 0)
  }
}

fn ensure_fruit_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_fruit(conn))
  case
    sqlite_pragma_assert.index_list_tsv(conn, "fruit"),
    sqlite_pragma_assert.index_info_tsv(conn, "fruit_by_name")
  {
    Ok(list_tsv), Ok(info_tsv) ->
      case list_tsv == expected_index_list && info_tsv == expected_index_info {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(sqlight.exec(
            "drop index if exists fruit_by_name;",
            conn,
          ))
          sqlight.exec(create_fruit_by_name_index_sql, conn)
        }
      }
    _, _ -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists fruit_by_name;",
        conn,
      ))
      sqlight.exec(create_fruit_by_name_index_sql, conn)
    }
  }
}

/// Applies this version: remove non-fruit user tables, align `fruit` columns and
/// identity indexes to the expected shape, then verify with pragmas.
pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlite_pragma_assert.drop_user_tables_except(conn, "fruit"))
  use _ <- result.try(ensure_fruit_table(conn))
  use _ <- result.try(ensure_fruit_indexes(conn))
  sqlite_pragma_assert.assert_pragma_snapshot(
    conn,
    ["fruit"],
    "fruit",
    expected_table_info,
    expected_index_list,
    "fruit_by_name",
    expected_index_info,
  )
  Ok(Nil)
}
