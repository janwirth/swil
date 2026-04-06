import sqlight
import swil/runtime/migration as mig

const create_fruit_table_sql = "create table \"fruit\" (
  \"id\" integer primary key autoincrement not null,
  \"name\" text,
  \"color\" text,
  \"price\" real,
  \"quantity\" integer,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_fruit_by_name_index_sql = "create unique index fruit_by_name on \"fruit\"(\"name\");"

const expected_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	0	NULL	0
2	color	TEXT	0	NULL	0
3	price	REAL	0	NULL	0
4	quantity	INTEGER	0	NULL	0
5	created_at	INTEGER	1	NULL	0
6	updated_at	INTEGER	1	NULL	0
7	deleted_at	INTEGER	0	NULL	0"

const expected_index_list = "seq	name	unique	origin	partial
0	fruit_by_name	1	c	0"

const expected_index_info = "seqno	cid	name
0	1	name"

const fruit_spec = mig.TableSpec(
  table: "fruit",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("name", "TEXT", 0, 0),
    mig.ColumnSpec("color", "TEXT", 0, 0),
    mig.ColumnSpec("price", "REAL", 0, 0),
    mig.ColumnSpec("quantity", "INTEGER", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_fruit_table_sql,
  indexes: [
    mig.IndexSpec("fruit_by_name", create_fruit_by_name_index_sql, expected_index_info),
  ],
  expected_table_info: expected_table_info,
  expected_index_list: expected_index_list,
)

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  mig.run(conn, [fruit_spec])
}
