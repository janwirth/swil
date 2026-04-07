//// Blueprint for a generated `migrate`: introspect user tables `importedtrack`, `tag`
//// columns / indexes, then move to the desired state using `ALTER TABLE` only
//// (add / drop column), never `DROP TABLE` / `CREATE TABLE` for shape fixes once those tables exist.

import sql/sqlite_ident

import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sql/pragma_assert.{type TableInfoRow} as sqlite_pragma_assert
import sqlight

const create_importedtrack_table_sql = "create table \"importedtrack\" (
  \"id\" integer primary key autoincrement not null,
  \"from_source_root\" text,
  \"title\" text,
  \"artist\" text,
  \"service\" text,
  \"source_id\" text,
  \"added_to_library_at\" integer,
  \"external_source_url\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"tags_list_id\" integer,
  \"deleted_at\" integer
);"

const create_importedtrack_by_from_source_root_service_source_id_index_sql = "create unique index importedtrack_by_from_source_root_service_source_id on \"importedtrack\"(\"from_source_root\", \"service\", \"source_id\");"

const expected_importedtrack_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	from_source_root	TEXT	0	NULL	0
2	title	TEXT	0	NULL	0
3	artist	TEXT	0	NULL	0
4	service	TEXT	0	NULL	0
5	source_id	TEXT	0	NULL	0
6	added_to_library_at	INTEGER	0	NULL	0
7	external_source_url	TEXT	0	NULL	0
8	created_at	INTEGER	1	NULL	0
9	updated_at	INTEGER	1	NULL	0
10	tags_list_id	INTEGER	0	NULL	0
11	deleted_at	INTEGER	0	NULL	0"

const expected_importedtrack_index_list = "seq	name	unique	origin	partial
0	importedtrack_by_from_source_root_service_source_id	1	c	0"

const expected_importedtrack_index_info = "seqno	cid	name
0	1	from_source_root
1	4	service
2	5	source_id"

type ImportedTrackCol {
  ImportedTrackCol(name: String, type_: String, notnull: Int, pk: Int)
}

const importedtrack_columns_wanted = [
  ImportedTrackCol("id", "INTEGER", 1, 1),
  ImportedTrackCol("from_source_root", "TEXT", 0, 0),
  ImportedTrackCol("title", "TEXT", 0, 0),
  ImportedTrackCol("artist", "TEXT", 0, 0),
  ImportedTrackCol("service", "TEXT", 0, 0),
  ImportedTrackCol("source_id", "TEXT", 0, 0),
  ImportedTrackCol("added_to_library_at", "INTEGER", 0, 0),
  ImportedTrackCol("external_source_url", "TEXT", 0, 0),
  ImportedTrackCol("created_at", "INTEGER", 1, 0),
  ImportedTrackCol("updated_at", "INTEGER", 1, 0),
  ImportedTrackCol("tags_list_id", "INTEGER", 0, 0),
  ImportedTrackCol("deleted_at", "INTEGER", 0, 0),
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

fn type_matches(expected: String, got: String) -> Bool {
  string.uppercase(got) == expected
}

fn drop_surplus_user_indexes_on_importedtrack(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "importedtrack"))
  list.try_each(rows, fn(pair) {
    let #(name, origin) = pair
    case
      origin == "c"
      && name != "importedtrack_by_from_source_root_service_source_id"
    {
      True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
      False -> Ok(Nil)
    }
  })
}

fn importedtrack_row_matches(want: ImportedTrackCol, got: TableInfoRow) -> Bool {
  want.name == got.name
  && type_matches(want.type_, got.type_)
  && want.notnull == got.notnull
  && want.pk == got.pk
  && case want.notnull {
    0 -> got.dflt == None || got.dflt == Some("")
    _ -> True
  }
}

fn first_surplus_column_importedtrack(
  rows: List(TableInfoRow),
  wanted: List(ImportedTrackCol),
) -> Option(String) {
  case
    list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) })
  {
    Ok(r) -> Some(r.name)
    Error(Nil) -> None
  }
}

fn first_mismatched_column_name_importedtrack(
  rows: List(TableInfoRow),
  wanted: List(ImportedTrackCol),
) -> Option(String) {
  case
    list.find_map(wanted, fn(w) {
      case list.find(rows, fn(r) { r.name == w.name }) {
        Error(Nil) -> Error(Nil)
        Ok(row) ->
          case importedtrack_row_matches(w, row) {
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

fn first_missing_column_importedtrack(
  rows: List(TableInfoRow),
  wanted: List(ImportedTrackCol),
) -> Option(ImportedTrackCol) {
  case
    list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) })
  {
    Ok(w) -> Some(w)
    Error(Nil) -> None
  }
}

fn alter_add_importedtrack_column_sql(w: ImportedTrackCol) -> String {
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
  <> sqlite_ident.quote("importedtrack")
  <> " add column "
  <> sqlite_ident.quote(w.name)
  <> " "
  <> fragment
  <> ";"
}

fn apply_one_importedtrack_column_fix(
  conn: sqlight.Connection,
  rows: List(TableInfoRow),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column_importedtrack(rows, importedtrack_columns_wanted) {
    Some(name) ->
      sqlight.exec(
        "alter table "
          <> sqlite_ident.quote("importedtrack")
          <> " drop column "
          <> sqlite_ident.quote(name)
          <> ";",
        conn,
      )
    None ->
      case
        first_mismatched_column_name_importedtrack(
          rows,
          importedtrack_columns_wanted,
        )
      {
        Some(name) ->
          sqlight.exec(
            "alter table "
              <> sqlite_ident.quote("importedtrack")
              <> " drop column "
              <> sqlite_ident.quote(name)
              <> ";",
            conn,
          )
        None ->
          case
            first_missing_column_importedtrack(
              rows,
              importedtrack_columns_wanted,
            )
          {
            Some(w) -> sqlight.exec(alter_add_importedtrack_column_sql(w), conn)
            None ->
              panic as "case_studies/tuna_db/migration: no column fix applies"
          }
      }
  }
}

fn reconcile_importedtrack_columns_loop(
  conn: sqlight.Connection,
  iter: Int,
) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
    True ->
      panic as "case_studies/tuna_db/migration: column reconcile did not converge"
    False -> {
      use rows <- result.try(sqlite_pragma_assert.table_info_rows(
        conn,
        "importedtrack",
      ))
      case
        list.length(rows) == list.length(importedtrack_columns_wanted)
        && list.all(importedtrack_columns_wanted, fn(w) {
          case list.find(rows, fn(r) { r.name == w.name }) {
            Ok(row) -> importedtrack_row_matches(w, row)
            Error(Nil) -> False
          }
        })
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(apply_one_importedtrack_column_fix(conn, rows))
          reconcile_importedtrack_columns_loop(conn, iter + 1)
        }
      }
    }
  }
}

fn ensure_importedtrack_table(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
  case list.contains(tables, "importedtrack") {
    False -> sqlight.exec(create_importedtrack_table_sql, conn)
    True -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists importedtrack_by_from_source_root_service_source_id;",
        conn,
      ))
      reconcile_importedtrack_columns_loop(conn, 0)
    }
  }
}

fn ensure_importedtrack_indexes(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_importedtrack(conn))
  case
    sqlite_pragma_assert.index_list_tsv(conn, "importedtrack"),
    sqlite_pragma_assert.index_info_tsv(
      conn,
      "importedtrack_by_from_source_root_service_source_id",
    )
  {
    Ok(list_tsv), Ok(info_tsv) ->
      case
        list_tsv == expected_importedtrack_index_list
        && info_tsv == expected_importedtrack_index_info
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(sqlight.exec(
            "drop index if exists importedtrack_by_from_source_root_service_source_id;",
            conn,
          ))
          sqlight.exec(
            create_importedtrack_by_from_source_root_service_source_id_index_sql,
            conn,
          )
        }
      }
    _, _ -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists importedtrack_by_from_source_root_service_source_id;",
        conn,
      ))
      sqlight.exec(
        create_importedtrack_by_from_source_root_service_source_id_index_sql,
        conn,
      )
    }
  }
}

const create_tag_table_sql = "create table \"tag\" (
  \"id\" integer primary key autoincrement not null,
  \"label\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_tag_by_label_index_sql = "create unique index tag_by_label on \"tag\"(\"label\");"

const expected_tag_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	label	TEXT	0	NULL	0
2	created_at	INTEGER	1	NULL	0
3	updated_at	INTEGER	1	NULL	0
4	deleted_at	INTEGER	0	NULL	0"

const expected_tag_index_list = "seq	name	unique	origin	partial
0	tag_by_label	1	c	0"

const expected_tag_index_info = "seqno	cid	name
0	1	label"

type TagCol {
  TagCol(name: String, type_: String, notnull: Int, pk: Int)
}

const tag_columns_wanted = [
  TagCol("id", "INTEGER", 1, 1),
  TagCol("label", "TEXT", 0, 0),
  TagCol("created_at", "INTEGER", 1, 0),
  TagCol("updated_at", "INTEGER", 1, 0),
  TagCol("deleted_at", "INTEGER", 0, 0),
]

fn drop_surplus_user_indexes_on_tag(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "tag"))
  list.try_each(rows, fn(pair) {
    let #(name, origin) = pair
    case origin == "c" && name != "tag_by_label" {
      True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
      False -> Ok(Nil)
    }
  })
}

fn tag_row_matches(want: TagCol, got: TableInfoRow) -> Bool {
  want.name == got.name
  && type_matches(want.type_, got.type_)
  && want.notnull == got.notnull
  && want.pk == got.pk
  && case want.notnull {
    0 -> got.dflt == None || got.dflt == Some("")
    _ -> True
  }
}

fn first_surplus_column_tag(
  rows: List(TableInfoRow),
  wanted: List(TagCol),
) -> Option(String) {
  case
    list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) })
  {
    Ok(r) -> Some(r.name)
    Error(Nil) -> None
  }
}

fn first_mismatched_column_name_tag(
  rows: List(TableInfoRow),
  wanted: List(TagCol),
) -> Option(String) {
  case
    list.find_map(wanted, fn(w) {
      case list.find(rows, fn(r) { r.name == w.name }) {
        Error(Nil) -> Error(Nil)
        Ok(row) ->
          case tag_row_matches(w, row) {
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

fn first_missing_column_tag(
  rows: List(TableInfoRow),
  wanted: List(TagCol),
) -> Option(TagCol) {
  case
    list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) })
  {
    Ok(w) -> Some(w)
    Error(Nil) -> None
  }
}

fn alter_add_tag_column_sql(w: TagCol) -> String {
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
  <> sqlite_ident.quote("tag")
  <> " add column "
  <> sqlite_ident.quote(w.name)
  <> " "
  <> fragment
  <> ";"
}

fn apply_one_tag_column_fix(
  conn: sqlight.Connection,
  rows: List(TableInfoRow),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column_tag(rows, tag_columns_wanted) {
    Some(name) ->
      sqlight.exec(
        "alter table "
          <> sqlite_ident.quote("tag")
          <> " drop column "
          <> sqlite_ident.quote(name)
          <> ";",
        conn,
      )
    None ->
      case first_mismatched_column_name_tag(rows, tag_columns_wanted) {
        Some(name) ->
          sqlight.exec(
            "alter table "
              <> sqlite_ident.quote("tag")
              <> " drop column "
              <> sqlite_ident.quote(name)
              <> ";",
            conn,
          )
        None ->
          case first_missing_column_tag(rows, tag_columns_wanted) {
            Some(w) -> sqlight.exec(alter_add_tag_column_sql(w), conn)
            None ->
              panic as "case_studies/tuna_db/migration: no column fix applies"
          }
      }
  }
}

fn reconcile_tag_columns_loop(
  conn: sqlight.Connection,
  iter: Int,
) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
    True ->
      panic as "case_studies/tuna_db/migration: column reconcile did not converge"
    False -> {
      use rows <- result.try(sqlite_pragma_assert.table_info_rows(conn, "tag"))
      case
        list.length(rows) == list.length(tag_columns_wanted)
        && list.all(tag_columns_wanted, fn(w) {
          case list.find(rows, fn(r) { r.name == w.name }) {
            Ok(row) -> tag_row_matches(w, row)
            Error(Nil) -> False
          }
        })
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(apply_one_tag_column_fix(conn, rows))
          reconcile_tag_columns_loop(conn, iter + 1)
        }
      }
    }
  }
}

fn ensure_tag_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
  case list.contains(tables, "tag") {
    False -> sqlight.exec(create_tag_table_sql, conn)
    True -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists tag_by_label;",
        conn,
      ))
      reconcile_tag_columns_loop(conn, 0)
    }
  }
}

fn ensure_tag_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_tag(conn))
  case
    sqlite_pragma_assert.index_list_tsv(conn, "tag"),
    sqlite_pragma_assert.index_info_tsv(conn, "tag_by_label")
  {
    Ok(list_tsv), Ok(info_tsv) ->
      case
        list_tsv == expected_tag_index_list
        && info_tsv == expected_tag_index_info
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(sqlight.exec(
            "drop index if exists tag_by_label;",
            conn,
          ))
          sqlight.exec(create_tag_by_label_index_sql, conn)
        }
      }
    _, _ -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists tag_by_label;",
        conn,
      ))
      sqlight.exec(create_tag_by_label_index_sql, conn)
    }
  }
}

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(
    sqlite_pragma_assert.drop_user_tables_except_any(conn, [
      "importedtrack",
      "tag",
    ]),
  )
  use _ <- result.try(ensure_importedtrack_table(conn))
  use _ <- result.try(ensure_importedtrack_indexes(conn))
  use _ <- result.try(ensure_tag_table(conn))
  use _ <- result.try(ensure_tag_indexes(conn))
  sqlite_pragma_assert.assert_pragma_snapshot(
    conn,
    ["importedtrack", "tag"],
    "importedtrack",
    expected_importedtrack_table_info,
    expected_importedtrack_index_list,
    "importedtrack_by_from_source_root_service_source_id",
    expected_importedtrack_index_info,
  )
  sqlite_pragma_assert.assert_pragma_snapshot(
    conn,
    ["importedtrack", "tag"],
    "tag",
    expected_tag_table_info,
    expected_tag_index_list,
    "tag_by_label",
    expected_tag_index_info,
  )
  Ok(Nil)
}
