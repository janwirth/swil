import gleam/dynamic/decode
import gleam/list
import gleam/result
import sql/pragma_assert as sqlite_pragma_assert
import sqlight
import swil/runtime/migration as mig

const create_importedtrack_table_sql = "create table \"importedtrack\" (
  \"id\" integer primary key autoincrement not null,
  \"title\" text,
  \"artist\" text,
  \"file_path\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_importedtrack_by_title_artist_index_sql = "create unique index importedtrack_by_title_artist on \"importedtrack\"(\"title\", \"artist\");"

const expected_importedtrack_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	title	TEXT	0	NULL	0
2	artist	TEXT	0	NULL	0
3	file_path	TEXT	0	NULL	0
4	created_at	INTEGER	1	NULL	0
5	updated_at	INTEGER	1	NULL	0
6	deleted_at	INTEGER	0	NULL	0"

const expected_importedtrack_index_list = "seq	name	unique	origin	partial
0	importedtrack_by_title_artist	1	c	0"

const expected_importedtrack_index_info = "seqno	cid	name
0	1	title
1	2	artist"

const create_tab_table_sql = "create table \"tab\" (
  \"id\" integer primary key autoincrement not null,
  \"label\" text,
  \"order\" real,
  \"view_config\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_tab_by_label_index_sql = "create unique index tab_by_label on \"tab\"(\"label\");"

const expected_tab_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	label	TEXT	0	NULL	0
2	order	REAL	0	NULL	0
3	view_config	TEXT	0	NULL	0
4	created_at	INTEGER	1	NULL	0
5	updated_at	INTEGER	1	NULL	0
6	deleted_at	INTEGER	0	NULL	0"

const expected_tab_index_list = "seq	name	unique	origin	partial
0	tab_by_label	1	c	0"

const expected_tab_index_info = "seqno	cid	name
0	1	label"

const create_tag_table_sql = "create table \"tag\" (
  \"id\" integer primary key autoincrement not null,
  \"label\" text,
  \"emoji\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_tag_by_label_index_sql = "create unique index tag_by_label on \"tag\"(\"label\");"

const expected_tag_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	label	TEXT	0	NULL	0
2	emoji	TEXT	0	NULL	0
3	created_at	INTEGER	1	NULL	0
4	updated_at	INTEGER	1	NULL	0
5	deleted_at	INTEGER	0	NULL	0"

const expected_tag_index_list = "seq	name	unique	origin	partial
0	tag_by_label	1	c	0"

const expected_tag_index_info = "seqno	cid	name
0	1	label"

const create_trackbucket_table_sql = "create table \"trackbucket\" (
  \"id\" integer primary key autoincrement not null,
  \"title\" text,
  \"artist\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_trackbucket_by_title_artist_index_sql = "create unique index trackbucket_by_title_artist on \"trackbucket\"(\"title\", \"artist\");"

const expected_trackbucket_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	title	TEXT	0	NULL	0
2	artist	TEXT	0	NULL	0
3	created_at	INTEGER	1	NULL	0
4	updated_at	INTEGER	1	NULL	0
5	deleted_at	INTEGER	0	NULL	0"

const expected_trackbucket_index_list = "seq	name	unique	origin	partial
0	trackbucket_by_title_artist	1	c	0"

const expected_trackbucket_index_info = "seqno	cid	name
0	1	title
1	2	artist"

const importedtrack_spec = mig.TableSpec(
  table: "importedtrack",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("title", "TEXT", 0, 0),
    mig.ColumnSpec("artist", "TEXT", 0, 0),
    mig.ColumnSpec("file_path", "TEXT", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_importedtrack_table_sql,
  indexes: [
    mig.IndexSpec(
      "importedtrack_by_title_artist",
      create_importedtrack_by_title_artist_index_sql,
      expected_importedtrack_index_info,
    ),
  ],
  expected_table_info: expected_importedtrack_table_info,
  expected_index_list: expected_importedtrack_index_list,
)

const tab_spec = mig.TableSpec(
  table: "tab",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("label", "TEXT", 0, 0),
    mig.ColumnSpec("order", "REAL", 0, 0),
    mig.ColumnSpec("view_config", "TEXT", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_tab_table_sql,
  indexes: [
    mig.IndexSpec("tab_by_label", create_tab_by_label_index_sql, expected_tab_index_info),
  ],
  expected_table_info: expected_tab_table_info,
  expected_index_list: expected_tab_index_list,
)

const tag_spec = mig.TableSpec(
  table: "tag",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("label", "TEXT", 0, 0),
    mig.ColumnSpec("emoji", "TEXT", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_tag_table_sql,
  indexes: [
    mig.IndexSpec("tag_by_label", create_tag_by_label_index_sql, expected_tag_index_info),
  ],
  expected_table_info: expected_tag_table_info,
  expected_index_list: expected_tag_index_list,
)

const trackbucket_spec = mig.TableSpec(
  table: "trackbucket",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("title", "TEXT", 0, 0),
    mig.ColumnSpec("artist", "TEXT", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_trackbucket_table_sql,
  indexes: [
    mig.IndexSpec(
      "trackbucket_by_title_artist",
      create_trackbucket_by_title_artist_index_sql,
      expected_trackbucket_index_info,
    ),
  ],
  expected_table_info: expected_trackbucket_table_info,
  expected_index_list: expected_trackbucket_index_list,
)

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(mig.run(conn, [
    importedtrack_spec,
    tab_spec,
    tag_spec,
    trackbucket_spec,
  ]))
  create_junction_tables(conn)
}

fn create_junction_tables(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlight.exec(create_trackbucket_tag_sql, conn))
  use _ <- result.try(ensure_trackbucket_tag_indexes(conn))
  Ok(Nil)
}

const create_trackbucket_tag_sql = "create table if not exists \"trackbucket_tag\" (\n  \"trackbucket_id\" integer not null,\n  \"tag_id\" integer not null,\n  \"value\" integer,\n  unique (\"trackbucket_id\", \"tag_id\")\n);"

/// Seek `(…)` on junction `trackbucket_tag` for filter `EXISTS` subqueries.
const create_trackbucket_tag_perf_index_sql = "create index trackbucket_tag_by_trackbucket_id_tag_id_value on \"trackbucket_tag\"(\"trackbucket_id\", \"tag_id\", \"value\");"

const expected_trackbucket_tag_index_list = "seq	name	unique	origin	partial\n0	trackbucket_tag_by_trackbucket_id_tag_id_value	0	c	0\n1	sqlite_autoindex_trackbucket_tag_1	1	u	0"

const expected_trackbucket_tag_perf_index_info = "seqno	cid	name\n0	0	trackbucket_id\n1	1	tag_id\n2	2	value"

const expected_trackbucket_tag_unique_index_info = "seqno	cid	name\n0	0	trackbucket_id\n1	1	tag_id"

fn drop_surplus_user_indexes_on_trackbucket_tag(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use rows <- result.try(
    sqlight.query(
      "pragma index_list(trackbucket_tag)",
      on: conn,
      with: [],
      expecting: {
        use name <- decode.field(1, decode.string)
        use origin <- decode.field(3, decode.string)
        decode.success(#(name, origin))
      },
    ),
  )
  list.try_each(rows, fn(pair) {
    let #(name, origin) = pair
    case
      origin == "c" && name != "trackbucket_tag_by_trackbucket_id_tag_id_value"
    {
      True -> sqlight.exec("drop index if exists " <> name <> ";", conn)
      False -> Ok(Nil)
    }
  })
}

fn ensure_trackbucket_tag_indexes(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(drop_surplus_user_indexes_on_trackbucket_tag(conn))
  case
    sqlite_pragma_assert.index_list_tsv(conn, "trackbucket_tag"),
    sqlite_pragma_assert.index_info_tsv(
      conn,
      "trackbucket_tag_by_trackbucket_id_tag_id_value",
    ),
    sqlite_pragma_assert.index_info_tsv(
      conn,
      "sqlite_autoindex_trackbucket_tag_1",
    )
  {
    Ok(list_tsv), Ok(perf_info), Ok(unique_info) ->
      case
        list_tsv == expected_trackbucket_tag_index_list
        && perf_info == expected_trackbucket_tag_perf_index_info
        && unique_info == expected_trackbucket_tag_unique_index_info
      {
        True -> Ok(Nil)
        False -> {
          use _ <- result.try(sqlight.exec(
            "drop index if exists trackbucket_tag_by_trackbucket_id_tag_id_value;",
            conn,
          ))
          sqlight.exec(create_trackbucket_tag_perf_index_sql, conn)
        }
      }
    _, _, _ -> {
      use _ <- result.try(sqlight.exec(
        "drop index if exists trackbucket_tag_by_trackbucket_id_tag_id_value;",
        conn,
      ))
      sqlight.exec(create_trackbucket_tag_perf_index_sql, conn)
    }
  }
}
