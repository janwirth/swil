import sqlight
import swil/runtime/migration as mig

const create_hippo_table_sql = "create table \"hippo\" (
  \"id\" integer primary key autoincrement not null,
  \"name\" text,
  \"gender\" text,
  \"date_of_birth\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"owner_human_id\" integer,
  \"deleted_at\" integer
);"

const create_hippo_by_name_date_of_birth_index_sql = "create unique index hippo_by_name_date_of_birth on \"hippo\"(\"name\", \"date_of_birth\");"

const expected_hippo_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	0	NULL	0
2	gender	TEXT	0	NULL	0
3	date_of_birth	TEXT	0	NULL	0
4	created_at	INTEGER	1	NULL	0
5	updated_at	INTEGER	1	NULL	0
6	owner_human_id	INTEGER	0	NULL	0
7	deleted_at	INTEGER	0	NULL	0"

const expected_hippo_index_list = "seq	name	unique	origin	partial
0	hippo_by_name_date_of_birth	1	c	0"

const expected_hippo_index_info = "seqno	cid	name
0	1	name
1	3	date_of_birth"

const create_human_table_sql = "create table \"human\" (
  \"id\" integer primary key autoincrement not null,
  \"name\" text,
  \"email\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_human_by_email_index_sql = "create unique index human_by_email on \"human\"(\"email\");"

const expected_human_table_info = "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	0	NULL	0
2	email	TEXT	0	NULL	0
3	created_at	INTEGER	1	NULL	0
4	updated_at	INTEGER	1	NULL	0
5	deleted_at	INTEGER	0	NULL	0"

const expected_human_index_list = "seq	name	unique	origin	partial
0	human_by_email	1	c	0"

const expected_human_index_info = "seqno	cid	name
0	2	email"

const hippo_spec = mig.TableSpec(
  table: "hippo",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("name", "TEXT", 0, 0),
    mig.ColumnSpec("gender", "TEXT", 0, 0),
    mig.ColumnSpec("date_of_birth", "TEXT", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("owner_human_id", "INTEGER", 0, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_hippo_table_sql,
  indexes: [
    mig.IndexSpec(
      "hippo_by_name_date_of_birth",
      create_hippo_by_name_date_of_birth_index_sql,
      expected_hippo_index_info,
    ),
  ],
  expected_table_info: expected_hippo_table_info,
  expected_index_list: expected_hippo_index_list,
)

const human_spec = mig.TableSpec(
  table: "human",
  columns: [
    mig.ColumnSpec("id", "INTEGER", 1, 1),
    mig.ColumnSpec("name", "TEXT", 0, 0),
    mig.ColumnSpec("email", "TEXT", 0, 0),
    mig.ColumnSpec("created_at", "INTEGER", 1, 0),
    mig.ColumnSpec("updated_at", "INTEGER", 1, 0),
    mig.ColumnSpec("deleted_at", "INTEGER", 0, 0),
  ],
  create_table_sql: create_human_table_sql,
  indexes: [
    mig.IndexSpec("human_by_email", create_human_by_email_index_sql, expected_human_index_info),
  ],
  expected_table_info: expected_human_table_info,
  expected_index_list: expected_human_index_list,
)

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  mig.run(conn, [hippo_spec, human_spec])
}
