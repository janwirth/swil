import sqlight
import swil/runtime/migration as mig

const create_importedtrack_table_sql = "create table \"importedtrack\" (
  \"id\" integer primary key autoincrement not null,
  \"title\" text,
  \"artist\" text,
  \"service\" text,
  \"source_id\" text,
  \"external_source_url\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_importedtrack_by_service_source_id_index_sql = "create unique index importedtrack_by_service_source_id on \"importedtrack\"(\"service\", \"source_id\");"

const expected_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	title	TEXT	0	NULL	0
2	artist	TEXT	0	NULL	0
3	service	TEXT	0	NULL	0
4	source_id	TEXT	0	NULL	0
5	external_source_url	TEXT	0	NULL	0
6	created_at	INTEGER	1	NULL	0
7	updated_at	INTEGER	1	NULL	0
8	deleted_at	INTEGER	0	NULL	0"

const expected_index_list = "seq	name	unique	origin	partial
0	importedtrack_by_service_source_id	1	c	0"

const expected_index_info = "seqno	cid	name
0	3	service
1	4	source_id"

const importedtrack_spec = mig.TableSpec(
  table: "importedtrack",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("title", "TEXT", 0, 0),
    mig.ColumnSpec("artist", "TEXT", 0, 0),
    mig.ColumnSpec("service", "TEXT", 0, 0),
    mig.ColumnSpec("source_id", "TEXT", 0, 0),
    mig.ColumnSpec("external_source_url", "TEXT", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_importedtrack_table_sql,
  indexes: [
    mig.IndexSpec(
      "importedtrack_by_service_source_id",
      create_importedtrack_by_service_source_id_index_sql,
      expected_index_info,
    ),
  ],
  expected_table_info: expected_table_info,
  expected_index_list: expected_index_list,
)

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  mig.run(conn, [importedtrack_spec])
}
