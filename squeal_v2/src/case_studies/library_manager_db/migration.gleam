//// Blueprint for a generated `migrate`: introspect user tables `importedtrack`, `tab`, `tag`, `trackbucket`
//// columns / indexes, then move to the desired state using `ALTER TABLE` only
//// (add / drop column), never `DROP TABLE` / `CREATE TABLE` for shape fixes once those tables exist.
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sql/pragma_assert.{type TableInfoRow} as sqlite_pragma_assert
import sqlight

const create_importedtrack_table_sql = "create table importedtrack (
  id integer primary key autoincrement not null,
  title text not null,
  artist text not null,
  file_path text not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer
);"

const create_importedtrack_by_title_artist_index_sql = "create unique index importedtrack_by_title_artist on importedtrack(title, artist);"

const expected_importedtrack_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	title	TEXT	1	NULL	0
2	artist	TEXT	1	NULL	0
3	file_path	TEXT	1	NULL	0
4	created_at	INTEGER	1	NULL	0
5	updated_at	INTEGER	1	NULL	0
6	deleted_at	INTEGER	0	NULL	0"

const expected_importedtrack_index_list = "seq	name	unique	origin	partial
0	importedtrack_by_title_artist	1	c	0"

const expected_importedtrack_index_info = "seqno	cid	name
0	1	title
1	2	artist"

type ImportedTrackCol {
  ImportedTrackCol(name: String, type_: String, notnull: Int, pk: Int)
}

const importedtrack_columns_wanted = [
  ImportedTrackCol("id", "INTEGER", 1, 1),
  ImportedTrackCol("title", "TEXT", 1, 0),
  ImportedTrackCol("artist", "TEXT", 1, 0),
  ImportedTrackCol("file_path", "TEXT", 1, 0),
  ImportedTrackCol("created_at", "INTEGER", 1, 0),
  ImportedTrackCol("updated_at", "INTEGER", 1, 0),
  ImportedTrackCol("deleted_at", "INTEGER", 0, 0),
]

fn pragma_index_name_origin_rows(conn: sqlight.Connection, table: String) -> Result(List(#(String, String)), sqlight.Error) {
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

fn drop_surplus_user_indexes_on_importedtrack(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "importedtrack"))
list.try_each(rows, fn(pair) {
  let #(name, origin) = pair
  case origin == "c" && name != "importedtrack_by_title_artist" {
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
"alter table importedtrack add column " <> w.name <> " " <> fragment <> ";"
}

fn apply_one_importedtrack_column_fix(
  conn: sqlight.Connection,
  rows: List(TableInfoRow),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column_importedtrack(rows, importedtrack_columns_wanted) {
  Some(name) ->
    sqlight.exec("alter table importedtrack drop column " <> name <> ";", conn)
  None ->
    case first_mismatched_column_name_importedtrack(rows, importedtrack_columns_wanted) {
      Some(name) ->
        sqlight.exec("alter table importedtrack drop column " <> name <> ";", conn)
      None ->
        case first_missing_column_importedtrack(rows, importedtrack_columns_wanted) {
          Some(w) -> sqlight.exec(alter_add_importedtrack_column_sql(w), conn)
            None ->
              panic as "case_studies/library_manager_db/migration: no column fix applies"
        }
    }
}
}

fn reconcile_importedtrack_columns_loop(conn: sqlight.Connection, iter: Int) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
  True ->
    panic as "case_studies/library_manager_db/migration: column reconcile did not converge"
  False -> {
      use rows <- result.try(
        sqlite_pragma_assert.table_info_rows(conn, "importedtrack"),
      )
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

fn ensure_importedtrack_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
case list.contains(tables, "importedtrack") {
  False -> sqlight.exec(create_importedtrack_table_sql, conn)
  True -> reconcile_importedtrack_columns_loop(conn, 0)
}
}

fn ensure_importedtrack_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_importedtrack(conn))
case
  sqlite_pragma_assert.index_list_tsv(conn, "importedtrack"),
  sqlite_pragma_assert.index_info_tsv(conn, "importedtrack_by_title_artist")
{
  Ok(list_tsv), Ok(info_tsv) ->
    case list_tsv == expected_importedtrack_index_list && info_tsv == expected_importedtrack_index_info {
      True -> Ok(Nil)
      False -> {
        use _ <- result.try(sqlight.exec(
          "drop index if exists importedtrack_by_title_artist;",
          conn,
        ))
        sqlight.exec(create_importedtrack_by_title_artist_index_sql, conn)
      }
    }
  _, _ -> {
    use _ <- result.try(sqlight.exec(
      "drop index if exists importedtrack_by_title_artist;",
      conn,
    ))
    sqlight.exec(create_importedtrack_by_title_artist_index_sql, conn)
  }
}
}

const create_tab_table_sql = "create table tab (
  id integer primary key autoincrement not null,
  label text not null,
  \"order\" real not null,
  view_config text not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer
);"

const create_tab_by_label_index_sql = "create unique index tab_by_label on tab(label);"

const expected_tab_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	label	TEXT	1	NULL	0
2	order	REAL	1	NULL	0
3	view_config	TEXT	1	NULL	0
4	created_at	INTEGER	1	NULL	0
5	updated_at	INTEGER	1	NULL	0
6	deleted_at	INTEGER	0	NULL	0"

const expected_tab_index_list = "seq	name	unique	origin	partial
0	tab_by_label	1	c	0"

const expected_tab_index_info = "seqno	cid	name
0	1	label"

type TabCol {
  TabCol(name: String, type_: String, notnull: Int, pk: Int)
}

const tab_columns_wanted = [
  TabCol("id", "INTEGER", 1, 1),
  TabCol("label", "TEXT", 1, 0),
  TabCol("order", "REAL", 1, 0),
  TabCol("view_config", "TEXT", 1, 0),
  TabCol("created_at", "INTEGER", 1, 0),
  TabCol("updated_at", "INTEGER", 1, 0),
  TabCol("deleted_at", "INTEGER", 0, 0),
]

fn tab_table_column_ident(name: String) -> String {
  case name == "order" {
    True -> "\"order\""
    False -> name
  }
}

fn drop_surplus_user_indexes_on_tab(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "tab"))
list.try_each(rows, fn(pair) {
  let #(name, origin) = pair
  case origin == "c" && name != "tab_by_label" {
    True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
    False -> Ok(Nil)
  }
})
}

fn tab_row_matches(want: TabCol, got: TableInfoRow) -> Bool {
  want.name == got.name
&& type_matches(want.type_, got.type_)
&& want.notnull == got.notnull
&& want.pk == got.pk
&& case want.notnull {
  0 -> got.dflt == None || got.dflt == Some("")
  _ -> True
}
}

fn first_surplus_column_tab(rows: List(TableInfoRow), wanted: List(TabCol)) -> Option(String) {
  case
  list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) })
{
  Ok(r) -> Some(r.name)
  Error(Nil) -> None
}
}

fn first_mismatched_column_name_tab(
  rows: List(TableInfoRow),
  wanted: List(TabCol),
) -> Option(String) {
  case
  list.find_map(wanted, fn(w) {
    case list.find(rows, fn(r) { r.name == w.name }) {
      Error(Nil) -> Error(Nil)
      Ok(row) ->
        case tab_row_matches(w, row) {
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

fn first_missing_column_tab(rows: List(TableInfoRow), wanted: List(TabCol)) -> Option(TabCol) {
  case
  list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) })
{
  Ok(w) -> Some(w)
  Error(Nil) -> None
}
}

fn alter_add_tab_column_sql(w: TabCol) -> String {
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
"alter table tab add column "
  <> tab_table_column_ident(w.name)
  <> " "
  <> fragment
  <> ";"
}

fn apply_one_tab_column_fix(conn: sqlight.Connection, rows: List(TableInfoRow)) -> Result(Nil, sqlight.Error) {
  case first_surplus_column_tab(rows, tab_columns_wanted) {
  Some(name) ->
    sqlight.exec(
      "alter table tab drop column " <> tab_table_column_ident(name) <> ";",
      conn,
    )
  None ->
    case first_mismatched_column_name_tab(rows, tab_columns_wanted) {
      Some(name) ->
        sqlight.exec(
          "alter table tab drop column " <> tab_table_column_ident(name) <> ";",
          conn,
        )
      None ->
        case first_missing_column_tab(rows, tab_columns_wanted) {
          Some(w) -> sqlight.exec(alter_add_tab_column_sql(w), conn)
            None ->
              panic as "case_studies/library_manager_db/migration: no column fix applies"
        }
    }
}
}

fn reconcile_tab_columns_loop(conn: sqlight.Connection, iter: Int) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
  True ->
    panic as "case_studies/library_manager_db/migration: column reconcile did not converge"
  False -> {
      use rows <- result.try(sqlite_pragma_assert.table_info_rows(conn, "tab"))
    case
      list.length(rows) == list.length(tab_columns_wanted)
      && list.all(tab_columns_wanted, fn(w) {
        case list.find(rows, fn(r) { r.name == w.name }) {
          Ok(row) -> tab_row_matches(w, row)
          Error(Nil) -> False
        }
      })
    {
      True -> Ok(Nil)
      False -> {
        use _ <- result.try(apply_one_tab_column_fix(conn, rows))
        reconcile_tab_columns_loop(conn, iter + 1)
      }
    }
  }
}
}

fn ensure_tab_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
case list.contains(tables, "tab") {
  False -> sqlight.exec(create_tab_table_sql, conn)
  True -> reconcile_tab_columns_loop(conn, 0)
}
}

fn ensure_tab_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_tab(conn))
case
  sqlite_pragma_assert.index_list_tsv(conn, "tab"),
  sqlite_pragma_assert.index_info_tsv(conn, "tab_by_label")
{
  Ok(list_tsv), Ok(info_tsv) ->
    case list_tsv == expected_tab_index_list && info_tsv == expected_tab_index_info {
      True -> Ok(Nil)
      False -> {
        use _ <- result.try(sqlight.exec(
          "drop index if exists tab_by_label;",
          conn,
        ))
        sqlight.exec(create_tab_by_label_index_sql, conn)
      }
    }
  _, _ -> {
    use _ <- result.try(sqlight.exec(
      "drop index if exists tab_by_label;",
      conn,
    ))
    sqlight.exec(create_tab_by_label_index_sql, conn)
  }
}
}

const create_tag_table_sql = "create table tag (
  id integer primary key autoincrement not null,
  label text not null,
  emoji text not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer
);"

const create_tag_by_label_index_sql = "create unique index tag_by_label on tag(label);"

const expected_tag_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	label	TEXT	1	NULL	0
2	emoji	TEXT	1	NULL	0
3	created_at	INTEGER	1	NULL	0
4	updated_at	INTEGER	1	NULL	0
5	deleted_at	INTEGER	0	NULL	0"

const expected_tag_index_list = "seq	name	unique	origin	partial
0	tag_by_label	1	c	0"

const expected_tag_index_info = "seqno	cid	name
0	1	label"

type TagCol {
  TagCol(name: String, type_: String, notnull: Int, pk: Int)
}

const tag_columns_wanted = [
  TagCol("id", "INTEGER", 1, 1),
  TagCol("label", "TEXT", 1, 0),
  TagCol("emoji", "TEXT", 1, 0),
  TagCol("created_at", "INTEGER", 1, 0),
  TagCol("updated_at", "INTEGER", 1, 0),
  TagCol("deleted_at", "INTEGER", 0, 0),
]

fn drop_surplus_user_indexes_on_tag(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
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

fn first_surplus_column_tag(rows: List(TableInfoRow), wanted: List(TagCol)) -> Option(String) {
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

fn first_missing_column_tag(rows: List(TableInfoRow), wanted: List(TagCol)) -> Option(TagCol) {
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
"alter table tag add column " <> w.name <> " " <> fragment <> ";"
}

fn apply_one_tag_column_fix(conn: sqlight.Connection, rows: List(TableInfoRow)) -> Result(Nil, sqlight.Error) {
  case first_surplus_column_tag(rows, tag_columns_wanted) {
  Some(name) ->
    sqlight.exec("alter table tag drop column " <> name <> ";", conn)
  None ->
    case first_mismatched_column_name_tag(rows, tag_columns_wanted) {
      Some(name) ->
        sqlight.exec("alter table tag drop column " <> name <> ";", conn)
      None ->
        case first_missing_column_tag(rows, tag_columns_wanted) {
          Some(w) -> sqlight.exec(alter_add_tag_column_sql(w), conn)
            None ->
              panic as "case_studies/library_manager_db/migration: no column fix applies"
        }
    }
}
}

fn reconcile_tag_columns_loop(conn: sqlight.Connection, iter: Int) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
  True ->
    panic as "case_studies/library_manager_db/migration: column reconcile did not converge"
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
  True -> reconcile_tag_columns_loop(conn, 0)
}
}

fn ensure_tag_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_tag(conn))
case
  sqlite_pragma_assert.index_list_tsv(conn, "tag"),
  sqlite_pragma_assert.index_info_tsv(conn, "tag_by_label")
{
  Ok(list_tsv), Ok(info_tsv) ->
    case list_tsv == expected_tag_index_list && info_tsv == expected_tag_index_info {
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

const create_trackbucket_table_sql = "create table trackbucket (
  id integer primary key autoincrement not null,
  title text not null,
  artist text not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer
);"

const create_trackbucket_by_title_artist_index_sql = "create unique index trackbucket_by_title_artist on trackbucket(title, artist);"

const expected_trackbucket_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	title	TEXT	1	NULL	0
2	artist	TEXT	1	NULL	0
3	created_at	INTEGER	1	NULL	0
4	updated_at	INTEGER	1	NULL	0
5	deleted_at	INTEGER	0	NULL	0"

const expected_trackbucket_index_list = "seq	name	unique	origin	partial
0	trackbucket_by_title_artist	1	c	0"

const expected_trackbucket_index_info = "seqno	cid	name
0	1	title
1	2	artist"

type TrackBucketCol {
  TrackBucketCol(name: String, type_: String, notnull: Int, pk: Int)
}

const trackbucket_columns_wanted = [
  TrackBucketCol("id", "INTEGER", 1, 1),
  TrackBucketCol("title", "TEXT", 1, 0),
  TrackBucketCol("artist", "TEXT", 1, 0),
  TrackBucketCol("created_at", "INTEGER", 1, 0),
  TrackBucketCol("updated_at", "INTEGER", 1, 0),
  TrackBucketCol("deleted_at", "INTEGER", 0, 0),
]

fn drop_surplus_user_indexes_on_trackbucket(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(pragma_index_name_origin_rows(conn, "trackbucket"))
list.try_each(rows, fn(pair) {
  let #(name, origin) = pair
  case origin == "c" && name != "trackbucket_by_title_artist" {
    True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
    False -> Ok(Nil)
  }
})
}

fn trackbucket_row_matches(want: TrackBucketCol, got: TableInfoRow) -> Bool {
  want.name == got.name
&& type_matches(want.type_, got.type_)
&& want.notnull == got.notnull
&& want.pk == got.pk
&& case want.notnull {
  0 -> got.dflt == None || got.dflt == Some("")
  _ -> True
}
}

fn first_surplus_column_trackbucket(
  rows: List(TableInfoRow),
  wanted: List(TrackBucketCol),
) -> Option(String) {
  case
  list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) })
{
  Ok(r) -> Some(r.name)
  Error(Nil) -> None
}
}

fn first_mismatched_column_name_trackbucket(
  rows: List(TableInfoRow),
  wanted: List(TrackBucketCol),
) -> Option(String) {
  case
  list.find_map(wanted, fn(w) {
    case list.find(rows, fn(r) { r.name == w.name }) {
      Error(Nil) -> Error(Nil)
      Ok(row) ->
        case trackbucket_row_matches(w, row) {
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

fn first_missing_column_trackbucket(
  rows: List(TableInfoRow),
  wanted: List(TrackBucketCol),
) -> Option(TrackBucketCol) {
  case
  list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) })
{
  Ok(w) -> Some(w)
  Error(Nil) -> None
}
}

fn alter_add_trackbucket_column_sql(w: TrackBucketCol) -> String {
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
"alter table trackbucket add column " <> w.name <> " " <> fragment <> ";"
}

fn apply_one_trackbucket_column_fix(
  conn: sqlight.Connection,
  rows: List(TableInfoRow),
) -> Result(Nil, sqlight.Error) {
  case first_surplus_column_trackbucket(rows, trackbucket_columns_wanted) {
  Some(name) ->
    sqlight.exec("alter table trackbucket drop column " <> name <> ";", conn)
  None ->
    case first_mismatched_column_name_trackbucket(rows, trackbucket_columns_wanted) {
      Some(name) ->
        sqlight.exec("alter table trackbucket drop column " <> name <> ";", conn)
      None ->
        case first_missing_column_trackbucket(rows, trackbucket_columns_wanted) {
          Some(w) -> sqlight.exec(alter_add_trackbucket_column_sql(w), conn)
            None ->
              panic as "case_studies/library_manager_db/migration: no column fix applies"
        }
    }
}
}

fn reconcile_trackbucket_columns_loop(conn: sqlight.Connection, iter: Int) -> Result(Nil, sqlight.Error) {
  case iter > 64 {
  True ->
    panic as "case_studies/library_manager_db/migration: column reconcile did not converge"
  False -> {
      use rows <- result.try(
        sqlite_pragma_assert.table_info_rows(conn, "trackbucket"),
      )
    case
      list.length(rows) == list.length(trackbucket_columns_wanted)
      && list.all(trackbucket_columns_wanted, fn(w) {
        case list.find(rows, fn(r) { r.name == w.name }) {
          Ok(row) -> trackbucket_row_matches(w, row)
          Error(Nil) -> False
        }
      })
    {
      True -> Ok(Nil)
      False -> {
        use _ <- result.try(apply_one_trackbucket_column_fix(conn, rows))
        reconcile_trackbucket_columns_loop(conn, iter + 1)
      }
    }
  }
}
}

fn ensure_trackbucket_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))
case list.contains(tables, "trackbucket") {
  False -> sqlight.exec(create_trackbucket_table_sql, conn)
  True -> reconcile_trackbucket_columns_loop(conn, 0)
}
}

fn ensure_trackbucket_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_trackbucket(conn))
case
  sqlite_pragma_assert.index_list_tsv(conn, "trackbucket"),
  sqlite_pragma_assert.index_info_tsv(conn, "trackbucket_by_title_artist")
{
  Ok(list_tsv), Ok(info_tsv) ->
    case list_tsv == expected_trackbucket_index_list && info_tsv == expected_trackbucket_index_info {
      True -> Ok(Nil)
      False -> {
        use _ <- result.try(sqlight.exec(
          "drop index if exists trackbucket_by_title_artist;",
          conn,
        ))
        sqlight.exec(create_trackbucket_by_title_artist_index_sql, conn)
      }
    }
  _, _ -> {
    use _ <- result.try(sqlight.exec(
      "drop index if exists trackbucket_by_title_artist;",
      conn,
    ))
    sqlight.exec(create_trackbucket_by_title_artist_index_sql, conn)
  }
}
}

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlite_pragma_assert.drop_user_tables_except_any(
  conn,
  ["importedtrack", "tab", "tag", "trackbucket"],
))
use _ <- result.try(ensure_importedtrack_table(conn))
use _ <- result.try(ensure_importedtrack_indexes(conn))
use _ <- result.try(ensure_tab_table(conn))
use _ <- result.try(ensure_tab_indexes(conn))
use _ <- result.try(ensure_tag_table(conn))
use _ <- result.try(ensure_tag_indexes(conn))
use _ <- result.try(ensure_trackbucket_table(conn))
use _ <- result.try(ensure_trackbucket_indexes(conn))
sqlite_pragma_assert.assert_pragma_snapshot(
  conn,
  ["importedtrack", "tab", "tag", "trackbucket"],
  "importedtrack",
  expected_importedtrack_table_info,
  expected_importedtrack_index_list,
  "importedtrack_by_title_artist",
  expected_importedtrack_index_info,
)
sqlite_pragma_assert.assert_pragma_snapshot(
  conn,
  ["importedtrack", "tab", "tag", "trackbucket"],
  "tab",
  expected_tab_table_info,
  expected_tab_index_list,
  "tab_by_label",
  expected_tab_index_info,
)
sqlite_pragma_assert.assert_pragma_snapshot(
  conn,
  ["importedtrack", "tab", "tag", "trackbucket"],
  "tag",
  expected_tag_table_info,
  expected_tag_index_list,
  "tag_by_label",
  expected_tag_index_info,
)
sqlite_pragma_assert.assert_pragma_snapshot(
  conn,
  ["importedtrack", "tab", "tag", "trackbucket"],
  "trackbucket",
  expected_trackbucket_table_info,
  expected_trackbucket_index_list,
  "trackbucket_by_title_artist",
  expected_trackbucket_index_info,
)
Ok(Nil)
}
