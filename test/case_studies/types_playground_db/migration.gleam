import sqlight
import swil/runtime/migration as mig

const create_mytrack_table_sql = "create table \"mytrack\" (
  \"id\" integer primary key autoincrement not null,
  \"added_to_playlist_at\" integer,
  \"name\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_mytrack_by_name_index_sql = "create unique index mytrack_by_name on \"mytrack\"(\"name\");"

const expected_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	added_to_playlist_at	INTEGER	0	NULL	0
2	name	TEXT	0	NULL	0
3	created_at	INTEGER	1	NULL	0
4	updated_at	INTEGER	1	NULL	0
5	deleted_at	INTEGER	0	NULL	0"

const expected_index_list = "seq	name	unique	origin	partial
0	mytrack_by_name	1	c	0"

const expected_index_info = "seqno	cid	name
0	2	name"

const mytrack_spec = mig.TableSpec(
  table: "mytrack",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("added_to_playlist_at", "INTEGER", 0, 0),
    mig.ColumnSpec("name", "TEXT", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_mytrack_table_sql,
  indexes: [
    mig.IndexSpec("mytrack_by_name", create_mytrack_by_name_index_sql, expected_index_info),
  ],
  expected_table_info: expected_table_info,
  expected_index_list: expected_index_list,
)

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  mig.run(conn, [mytrack_spec])
}
