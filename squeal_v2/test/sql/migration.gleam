// given two very basic schemas, generate the migration sql
// the migrations should be idempotent - fuzz order with 3 different variants
// write in style of squeal schema
import generators/migration
import schema_definition
import sqlight

const schema1 = "
import gleam/option

pub type Fruit {
    Fruit(
        name: option.Option(String),
        color: option.Option(String),
        price: option.Option(Float),
        quantity: option.Option(Int),
    )
}
pub type FruitIdentities {
    ByName(name: String)
}
"

const schema2 = "
import gleam/option
pub type Animal {
    Animal(
        name: String,
        species: String,
        age: Int,
        color: String,
    )
}
pub type AnimalIdentities {
    ByName(name: String)
}
"

// they should include
// unique index: by_name: name
// magic fields: created_at, updated_at, deleted_at

// table columns: entity fields plus dsl.MagicFields (timestamps as INTEGER; deleted_at nullable)
const expected_table_info_in_pragma_schema1 = "
cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	1	NULL	0
2	color	TEXT	1	NULL	0
3	price	REAL	1	NULL	0
4	quantity	INTEGER	1	NULL	0
5	created_at	INTEGER	1	NULL	0
6	updated_at	INTEGER	1	NULL	0
7	deleted_at	INTEGER	0	NULL	0
"

const expected_table_info_in_pragma_schema2 = "
cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	name	TEXT	1	NULL	0
2	species	TEXT	1	NULL	0
3	age	INTEGER	1	NULL	0
4	color	TEXT	1	NULL	0
5	created_at	INTEGER	1	NULL	0
6	updated_at	INTEGER	1	NULL	0
7	deleted_at	INTEGER	0	NULL	0
"

// FruitIdentities / AnimalIdentities: ByName(name) -> unique index on name (SQLite PRAGMA index_list)
const expected_index_list_in_pragma_schema1 = "
seq	name	unique	origin	partial
0	fruit_by_name	1	c	0
"

const expected_index_info_fruit_by_name = "
seqno	cid	name
0	1	name
"

const expected_index_list_in_pragma_schema2 = "
seq	name	unique	origin	partial
0	animal_by_name	1	c	0
"

const expected_index_info_animal_by_name = "
seqno	cid	name
0	1	name
"

pub fn idempotent_migration_test() {
  let assert Ok(parsed1) = schema_definition.parse_module(schema1)
  let assert Ok(parsed2) = schema_definition.parse_module(schema2)

  let assert migration = migration.generate_migration(parsed1)
  let assert migration2 = migration.generate_migration(parsed2)
  let assert Ok(conn) = sqlight.open(":memory:")
  // execute schema 1, check pragma, , then again same, then 2 same (2x,) then back and forth.
}
