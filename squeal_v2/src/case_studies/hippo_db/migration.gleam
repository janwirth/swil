//// Manual pragma migration for `case_studies/hippo_schema` (Hippo + Human).
//// Matches the fruit/animal blueprint: reconcile columns with `ALTER TABLE`, keep
//// both tables when this migration runs; other user tables are dropped.
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sql/pragma_assert.{type TableInfoRow} as sqlite_pragma_assert
import sqlight

const create_hippo_table_sql = "create table hippo (
  id integer primary key autoincrement not null,
  name text not null,
  gender text not null,
  date_of_birth text not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer
);"

const create_hippo_by_name_dob_index_sql = "create unique index hippo_by_name_date_of_birth on hippo(name, date_of_birth);"

const expected_hippo_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	1	NULL	0
2	gender	TEXT	1	NULL	0
3	date_of_birth	TEXT	1	NULL	0
4	created_at	INTEGER	1	NULL	0
5	updated_at	INTEGER	1	NULL	0
6	deleted_at	INTEGER	0	NULL	0"

const expected_hippo_index_list = "seq	name	unique	origin	partial
0	hippo_by_name_date_of_birth	1	c	0"

const expected_hippo_index_info = "seqno	cid	name
0	1	name
1	3	date_of_birth"

type HippoCol {
  HippoCol(name: String, type_: String, notnull: Int, pk: Int)
}

const hippo_columns_wanted = [
  HippoCol("id", "INTEGER", 1, 1),
  HippoCol("name", "TEXT", 1, 0),
  HippoCol("gender", "TEXT", 1, 0),
  HippoCol("date_of_birth", "TEXT", 1, 0),
  HippoCol("created_at", "INTEGER", 1, 0),
  HippoCol("updated_at", "INTEGER", 1, 0),
  HippoCol("deleted_at", "INTEGER", 0, 0),
]

const create_human_table_sql = "create table human (
  id integer primary key autoincrement not null,
  name text not null,
  email text not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer
);"

const create_human_by_email_index_sql = "create unique index human_by_email on human(email);"

const expected_human_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	1	NULL	0
2	email	TEXT	1	NULL	0
3	created_at	INTEGER	1	NULL	0
4	updated_at	INTEGER	1	NULL	0
5	deleted_at	INTEGER	0	NULL	0"

const expected_human_index_list = "seq	name	unique	origin	partial
0	human_by_email	1	c	0"

const expected_human_index_info = "seqno	cid	name
0	2	email"

type HumanCol {
  HumanCol(name: String, type_: String, notnull: Int, pk: Int)
}

const human_columns_wanted = [
  HumanCol("id", "INTEGER", 1, 1),
  HumanCol("name", "TEXT", 1, 0),
  HumanCol("email", "TEXT", 1, 0),
  HumanCol("created_at", "INTEGER", 1, 0),
  HumanCol("updated_at", "INTEGER", 1, 0),
  HumanCol("deleted_at", "INTEGER", 0, 0),
]

const exact_tables = ["hippo", "human"]

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

fn drop_surplus_user_indexes_on_hippo(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "hippo"))
  list.try_each(rows, fn(pair) {
    let #(name, origin) = pair
    case origin == "c" && name != "hippo_by_name_date_of_birth" {
      True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
      False -> Ok(Nil)
    }
  })
}

fn drop_surplus_user_indexes_on_human(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "human"))
  list.try_each(rows, fn(pair) {
    let #(name, origin) = pair
    case origin == "c" && name != "human_by_email" {
      True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
      False -> Ok(Nil)
    }
  })
}

fn type_matches(expected: String, got: String) -> Bool {
  string.uppercase(got) == expected
}

fn hippo_row_matches(want: HippoCol, got: TableInfoRow) -> Bool {
  want.name == got.name
  && type_matches(want.type_, got.type_)
  && want.notnull == got.notnull
  && want.pk == got.pk
  && case want.notnull {
    0 -> got.dflt == None || got.dflt == Some("")
    _ -> True
  }
}

fn human_row_matches(want: HumanCol, got: TableInfoRow) -> Bool {
  want.name == got.name
  && type_matches(want.type_, got.type_)
  && want.notnull == got.notnull
  && want.pk == got.pk
  && case want.notnull {
    0 -> got.dflt == None || got.dflt == Some("")
    _ -> True
  }
}

fn first_surplus_column_hippo(
  rows: List(TableInfoRow),
  wanted: List(HippoCol),
) -> Option(String) {
  case list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) }) {
    Ok(r) -> Some(r.name)
    Error(Nil) -> None
  }
}

fn first_mismatched_hippo(
  rows: List(TableInfoRow),
  wanted: List(HippoCol),
) -> Option(String) {
  case
    list.find_map(wanted, fn(w) {
      case list.find(rows, fn(r) { r.name == w.name }) {
        Error(Nil) -> Error(Nil)
        Ok(row) ->
          case hippo_row_matches(w, row) {
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

fn first_missing_hippo(
  rows: List(TableInfoRow),
  wanted: List(HippoCol),
) -> Option(HippoCol) {
  case list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) }) {
    Ok(w) -> Some(w)
    Error(Nil) -> None
  }
}

fn alter_add_hippo_column_sql(w: HippoCol) -> String {
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
  "alter table hippo add column " <> w.name <> " " <> fragment <> ";"
}

fn apply_one_hippo_column_fix(
  conn: sqlight.Connection,
  rows: List(TableInfoRow),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column_hippo(rows, hippo_columns_wanted) {
    Some(name) ->
      sqlight.exec("alter table hippo drop column " <> name <> ";", conn)
    None ->
      case first_mismatched_hippo(rows, hippo_columns_wanted) {
        Some(name) ->
          sqlight.exec("alter table hippo drop column " <> name <> ";", conn)
        None ->
          case first_missing_hippo(rows, hippo_columns_wanted) {
            Some(w) -> sqlight.exec(alter_add_hippo_column_sql(w), conn)
            None ->
              panic as "case_studies/hippo_db/migration: no column fix applies (hippo)"
          }
      }
  }
}

fn reconcile_hippo_columns_loop(
  conn: sqlight.Connection,
  iter: Int,
) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
    True ->
      panic as "case_studies/hippo_db/migration: column reconcile did not converge (hippo)"
    False -> {
      use rows <- result.try(sqlite_pragma_assert.table_info_rows(conn, "hippo"))
      case
        list.length(rows) == list.length(hippo_columns_wanted)
        && list.all(hippo_columns_wanted, fn(w) {
          case list.find(rows, fn(r) { r.name == w.name }) {
            Ok(row) -> hippo_row_matches(w, row)
            Error(Nil) -> False
          }
        })
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(apply_one_hippo_column_fix(conn, rows))
          reconcile_hippo_columns_loop(conn, iter + 1)
        }
      }
    }
  }
}

fn ensure_hippo_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
  case list.contains(tables, "hippo") {
    False -> sqlight.exec(create_hippo_table_sql, conn)
    True -> reconcile_hippo_columns_loop(conn, 0)
  }
}

fn ensure_hippo_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_hippo(conn))
  case
    sqlite_pragma_assert.index_list_tsv(conn, "hippo"),
    sqlite_pragma_assert.index_info_tsv(conn, "hippo_by_name_date_of_birth")
  {
    Ok(list_tsv), Ok(info_tsv) ->
      case list_tsv == expected_hippo_index_list
        && info_tsv == expected_hippo_index_info
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(sqlight.exec(
            "drop index if exists hippo_by_name_date_of_birth;",
            conn,
          ))
          sqlight.exec(create_hippo_by_name_dob_index_sql, conn)
        }
      }
    _, _ -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists hippo_by_name_date_of_birth;",
        conn,
      ))
      sqlight.exec(create_hippo_by_name_dob_index_sql, conn)
    }
  }
}

fn first_surplus_column_human(
  rows: List(TableInfoRow),
  wanted: List(HumanCol),
) -> Option(String) {
  case list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) }) {
    Ok(r) -> Some(r.name)
    Error(Nil) -> None
  }
}

fn first_mismatched_human(
  rows: List(TableInfoRow),
  wanted: List(HumanCol),
) -> Option(String) {
  case
    list.find_map(wanted, fn(w) {
      case list.find(rows, fn(r) { r.name == w.name }) {
        Error(Nil) -> Error(Nil)
        Ok(row) ->
          case human_row_matches(w, row) {
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

fn first_missing_human(
  rows: List(TableInfoRow),
  wanted: List(HumanCol),
) -> Option(HumanCol) {
  case list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) }) {
    Ok(w) -> Some(w)
    Error(Nil) -> None
  }
}

fn alter_add_human_column_sql(w: HumanCol) -> String {
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
  "alter table human add column " <> w.name <> " " <> fragment <> ";"
}

fn apply_one_human_column_fix(
  conn: sqlight.Connection,
  rows: List(TableInfoRow),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column_human(rows, human_columns_wanted) {
    Some(name) ->
      sqlight.exec("alter table human drop column " <> name <> ";", conn)
    None ->
      case first_mismatched_human(rows, human_columns_wanted) {
        Some(name) ->
          sqlight.exec("alter table human drop column " <> name <> ";", conn)
        None ->
          case first_missing_human(rows, human_columns_wanted) {
            Some(w) -> sqlight.exec(alter_add_human_column_sql(w), conn)
            None ->
              panic as "case_studies/hippo_db/migration: no column fix applies (human)"
          }
      }
  }
}

fn reconcile_human_columns_loop(
  conn: sqlight.Connection,
  iter: Int,
) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
    True ->
      panic as "case_studies/hippo_db/migration: column reconcile did not converge (human)"
    False -> {
      use rows <- result.try(sqlite_pragma_assert.table_info_rows(conn, "human"))
      case
        list.length(rows) == list.length(human_columns_wanted)
        && list.all(human_columns_wanted, fn(w) {
          case list.find(rows, fn(r) { r.name == w.name }) {
            Ok(row) -> human_row_matches(w, row)
            Error(Nil) -> False
          }
        })
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(apply_one_human_column_fix(conn, rows))
          reconcile_human_columns_loop(conn, iter + 1)
        }
      }
    }
  }
}

fn ensure_human_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
  case list.contains(tables, "human") {
    False -> sqlight.exec(create_human_table_sql, conn)
    True -> reconcile_human_columns_loop(conn, 0)
  }
}

fn ensure_human_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_human(conn))
  case
    sqlite_pragma_assert.index_list_tsv(conn, "human"),
    sqlite_pragma_assert.index_info_tsv(conn, "human_by_email")
  {
    Ok(list_tsv), Ok(info_tsv) ->
      case list_tsv == expected_human_index_list && info_tsv == expected_human_index_info
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(sqlight.exec(
            "drop index if exists human_by_email;",
            conn,
          ))
          sqlight.exec(create_human_by_email_index_sql, conn)
        }
      }
    _, _ -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists human_by_email;",
        conn,
      ))
      sqlight.exec(create_human_by_email_index_sql, conn)
    }
  }
}

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlite_pragma_assert.drop_user_tables_except_any(
    conn,
    exact_tables,
  ))
  use _ <- result.try(ensure_hippo_table(conn))
  use _ <- result.try(ensure_human_table(conn))
  use _ <- result.try(ensure_hippo_indexes(conn))
  use _ <- result.try(ensure_human_indexes(conn))
  sqlite_pragma_assert.assert_pragma_snapshot(
    conn,
    exact_tables,
    "hippo",
    expected_hippo_table_info,
    expected_hippo_index_list,
    "hippo_by_name_date_of_birth",
    expected_hippo_index_info,
  )
  sqlite_pragma_assert.assert_pragma_snapshot(
    conn,
    exact_tables,
    "human",
    expected_human_table_info,
    expected_human_index_list,
    "human_by_email",
    expected_human_index_info,
  )
  Ok(Nil)
}
