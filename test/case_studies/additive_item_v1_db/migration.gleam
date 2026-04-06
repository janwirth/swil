//// Blueprint for a generated `migrate`: introspect user tables and `item` columns /
//// indexes, then move to the desired state using `ALTER TABLE` only (add / drop column),
//// never `DROP TABLE` / `CREATE TABLE` for shape fixes once `item` exists.

import sql/sqlite_ident

import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sql/pragma_assert.{type TableInfoRow} as sqlite_pragma_assert
import sqlight

const create_item_table_sql = "create table \"item\" (
  \"id\" integer primary key autoincrement not null,
  \"name\" text,
  \"age\" integer,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_item_by_name_age_index_sql = "create unique index item_by_name_age on \"item\"(\"name\", \"age\");"

const expected_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	0	NULL	0
2	age	INTEGER	0	NULL	0
3	created_at	INTEGER	1	NULL	0
4	updated_at	INTEGER	1	NULL	0
5	deleted_at	INTEGER	0	NULL	0"

const expected_index_list = "seq	name	unique	origin	partial
0	item_by_name_age	1	c	0"

const expected_index_info = "seqno	cid	name
0	1	name
1	2	age"

type ItemCol {
  ItemCol(name: String, type_: String, notnull: Int, pk: Int)
}

const item_columns_wanted = [
  ItemCol("id", "INTEGER", 1, 1),
  ItemCol("name", "TEXT", 0, 0),
  ItemCol("age", "INTEGER", 0, 0),
  ItemCol("created_at", "INTEGER", 1, 0),
  ItemCol("updated_at", "INTEGER", 1, 0),
  ItemCol("deleted_at", "INTEGER", 0, 0),
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

fn drop_surplus_user_indexes_on_item(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "item"))
  list.try_each(rows, fn(pair) {
    let #(name, origin) = pair
    case origin == "c" && name != "item_by_name_age" {
      True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
      False -> Ok(Nil)
    }
  })
}

fn type_matches(expected: String, got: String) -> Bool {
  string.uppercase(got) == expected
}

fn item_row_matches(want: ItemCol, got: TableInfoRow) -> Bool {
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
  wanted: List(ItemCol),
) -> Option(String) {
  case
    list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) })
  {
    Ok(r) -> Some(r.name)
    Error(Nil) -> None
  }
}

fn first_mismatched_column_name(
  rows: List(TableInfoRow),
  wanted: List(ItemCol),
) -> Option(String) {
  case
    list.find_map(wanted, fn(w) {
      case list.find(rows, fn(r) { r.name == w.name }) {
        Error(Nil) -> Error(Nil)
        Ok(row) ->
          case item_row_matches(w, row) {
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
  wanted: List(ItemCol),
) -> Option(ItemCol) {
  case
    list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) })
  {
    Ok(w) -> Some(w)
    Error(Nil) -> None
  }
}

fn alter_add_item_column_sql(w: ItemCol) -> String {
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
  <> sqlite_ident.quote("item")
  <> " add column "
  <> sqlite_ident.quote(w.name)
  <> " "
  <> fragment
  <> ";"
}

fn apply_one_item_column_fix(
  conn: sqlight.Connection,
  rows: List(TableInfoRow),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column(rows, item_columns_wanted) {
    Some(name) ->
      sqlight.exec(
        "alter table "
          <> sqlite_ident.quote("item")
          <> " drop column "
          <> sqlite_ident.quote(name)
          <> ";",
        conn,
      )
    None ->
      case first_mismatched_column_name(rows, item_columns_wanted) {
        Some(name) ->
          sqlight.exec(
            "alter table "
              <> sqlite_ident.quote("item")
              <> " drop column "
              <> sqlite_ident.quote(name)
              <> ";",
            conn,
          )
        None ->
          case first_missing_column(rows, item_columns_wanted) {
            Some(w) -> sqlight.exec(alter_add_item_column_sql(w), conn)
            None ->
              panic as "case_studies/additive_item_v1_db/migration: no column fix applies"
          }
      }
  }
}

fn reconcile_item_columns_loop(
  conn: sqlight.Connection,
  iter: Int,
) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
    True ->
      panic as "case_studies/additive_item_v1_db/migration: column reconcile did not converge"
    False -> {
      use rows <- result.try(sqlite_pragma_assert.table_info_rows(conn, "item"))
      case
        list.length(rows) == list.length(item_columns_wanted)
        && list.all(item_columns_wanted, fn(w) {
          case list.find(rows, fn(r) { r.name == w.name }) {
            Ok(row) -> item_row_matches(w, row)
            Error(Nil) -> False
          }
        })
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(apply_one_item_column_fix(conn, rows))
          reconcile_item_columns_loop(conn, iter + 1)
        }
      }
    }
  }
}

fn ensure_item_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
  case list.contains(tables, "item") {
    False -> sqlight.exec(create_item_table_sql, conn)
    True -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists item_by_name_age;",
        conn,
      ))
      reconcile_item_columns_loop(conn, 0)
    }
  }
}

fn ensure_item_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_item(conn))
  case
    sqlite_pragma_assert.index_list_tsv(conn, "item"),
    sqlite_pragma_assert.index_info_tsv(conn, "item_by_name_age")
  {
    Ok(list_tsv), Ok(info_tsv) ->
      case list_tsv == expected_index_list && info_tsv == expected_index_info {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(sqlight.exec(
            "drop index if exists item_by_name_age;",
            conn,
          ))
          sqlight.exec(create_item_by_name_age_index_sql, conn)
        }
      }
    _, _ -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists item_by_name_age;",
        conn,
      ))
      sqlight.exec(create_item_by_name_age_index_sql, conn)
    }
  }
}

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlite_pragma_assert.drop_user_tables_except(conn, "item"))
  use _ <- result.try(ensure_item_table(conn))
  use _ <- result.try(ensure_item_indexes(conn))
  sqlite_pragma_assert.assert_pragma_snapshot(
    conn,
    ["item"],
    "item",
    expected_table_info,
    expected_index_list,
    "item_by_name_age",
    expected_index_info,
  )
  Ok(Nil)
}
