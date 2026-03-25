// given two very basic schemas, generate the migration sql
// the migrations should be idempotent - fuzz order with 3 different variants
// write in style of squeal schema
import generators/migration
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
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
        identities: FruitIdentities,
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
        name: option.Option(String),
        species: option.Option(String),
        age: option.Option(Int),
        color: option.Option(String),
        identities: AnimalIdentities,
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

fn pragma_table_info_snapshot(
  conn: sqlight.Connection,
  table: String,
) -> Result(String, sqlight.Error) {
  use rows <- result.try(
    sqlight.query(
      "pragma table_info(" <> table <> ")",
      on: conn,
      with: [],
      expecting: table_info_row_decoder(),
    ),
  )
  Ok(format_table_info_tsv(rows))
}

fn table_info_row_decoder() -> decode.Decoder(
  #(Int, String, String, Int, Option(String), Int),
) {
  use cid <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  use type_ <- decode.field(2, decode.string)
  use notnull <- decode.field(3, decode.int)
  use dflt <- decode.field(4, decode.optional(decode.string))
  use pk <- decode.field(5, decode.int)
  decode.success(#(cid, name, type_, notnull, dflt, pk))
}

fn format_table_info_tsv(
  rows: List(#(Int, String, String, Int, Option(String), Int)),
) -> String {
  let header = "cid\tname\ttype\tnotnull\tdflt_value\tpk"
  let lines =
    list.map(rows, fn(r) {
      let #(cid, name, type_, notnull, dflt, pk) = r
      let dflt_str = case dflt {
        None -> "NULL"
        Some("") -> "NULL"
        Some(s) -> s
      }
      int.to_string(cid)
      <> "\t"
      <> name
      <> "\t"
      <> type_
      <> "\t"
      <> int.to_string(notnull)
      <> "\t"
      <> dflt_str
      <> "\t"
      <> int.to_string(pk)
    })
  string.join([header, ..lines], "\n")
}

fn pragma_index_list_snapshot(
  conn: sqlight.Connection,
  table: String,
) -> Result(String, sqlight.Error) {
  use rows <- result.try(
    sqlight.query(
      "pragma index_list(" <> table <> ")",
      on: conn,
      with: [],
      expecting: index_list_row_decoder(),
    ),
  )
  Ok(format_index_list_tsv(rows))
}

fn index_list_row_decoder() -> decode.Decoder(#(Int, String, Int, String, Int)) {
  use seq <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  use unique <- decode.field(2, decode.int)
  use origin <- decode.field(3, decode.string)
  use partial <- decode.field(4, decode.int)
  decode.success(#(seq, name, unique, origin, partial))
}

fn format_index_list_tsv(rows: List(#(Int, String, Int, String, Int))) -> String {
  let header = "seq\tname\tunique\torigin\tpartial"
  let lines =
    list.map(rows, fn(r) {
      let #(seq, name, unique, origin, partial) = r
      int.to_string(seq)
      <> "\t"
      <> name
      <> "\t"
      <> int.to_string(unique)
      <> "\t"
      <> origin
      <> "\t"
      <> int.to_string(partial)
    })
  string.join([header, ..lines], "\n")
}

fn pragma_index_info_snapshot(
  conn: sqlight.Connection,
  index_name: String,
) -> Result(String, sqlight.Error) {
  use rows <- result.try(
    sqlight.query(
      "pragma index_info(" <> index_name <> ")",
      on: conn,
      with: [],
      expecting: index_info_row_decoder(),
    ),
  )
  Ok(format_index_info_tsv(rows))
}

fn index_info_row_decoder() -> decode.Decoder(#(Int, Int, String)) {
  use seqno <- decode.field(0, decode.int)
  use cid <- decode.field(1, decode.int)
  use name <- decode.field(2, decode.string)
  decode.success(#(seqno, cid, name))
}

fn format_index_info_tsv(rows: List(#(Int, Int, String))) -> String {
  let header = "seqno\tcid\tname"
  let lines =
    list.map(rows, fn(r) {
      let #(seqno, cid, name) = r
      int.to_string(seqno)
      <> "\t"
      <> int.to_string(cid)
      <> "\t"
      <> name
    })
  string.join([header, ..lines], "\n")
}

fn assert_pragma_snapshot(
  conn: sqlight.Connection,
  table: String,
  expected_table_info: String,
  expected_indexes: String,
  by_name_index: String,
  expected_index_info: String,
) -> Nil {
  let assert Ok(got_info) = pragma_table_info_snapshot(conn, table)
  let assert Ok(got_list) = pragma_index_list_snapshot(conn, table)
  let assert Ok(got_ix) = pragma_index_info_snapshot(conn, by_name_index)
  let assert True = string.trim(got_info) == string.trim(expected_table_info)
  let assert True = string.trim(got_list) == string.trim(expected_indexes)
  let assert True = string.trim(got_ix) == string.trim(expected_index_info)
  Nil
}

fn assert_schema1_pragmas(conn: sqlight.Connection) -> Nil {
  assert_pragma_snapshot(
    conn,
    "fruit",
    expected_table_info_in_pragma_schema1,
    expected_index_list_in_pragma_schema1,
    "fruit_by_name",
    expected_index_info_fruit_by_name,
  )
}

fn assert_schema2_pragmas(conn: sqlight.Connection) -> Nil {
  assert_pragma_snapshot(
    conn,
    "animal",
    expected_table_info_in_pragma_schema2,
    expected_index_list_in_pragma_schema2,
    "animal_by_name",
    expected_index_info_animal_by_name,
  )
}

pub fn idempotent_migration_test() {
  let assert Ok(parsed1) = schema_definition.parse_module(schema1)
  let assert Ok(parsed2) = schema_definition.parse_module(schema2)

  let migration1 = migration.generate_migration(parsed1)
  let migration2 = migration.generate_migration(parsed2)
  let assert Ok(conn) = sqlight.open(":memory:")

  let assert Ok(Nil) = sqlight.exec(migration1, conn)
  assert_schema1_pragmas(conn)

  let assert Ok(Nil) = sqlight.exec(migration1, conn)
  assert_schema1_pragmas(conn)

  let assert Ok(Nil) = sqlight.exec(migration2, conn)
  assert_schema1_pragmas(conn)
  assert_schema2_pragmas(conn)

  let assert Ok(Nil) = sqlight.exec(migration2, conn)
  assert_schema1_pragmas(conn)
  assert_schema2_pragmas(conn)

  let assert Ok(Nil) = sqlight.exec(migration1, conn)
  assert_schema1_pragmas(conn)
  assert_schema2_pragmas(conn)

  let assert Ok(Nil) = sqlight.exec(migration2, conn)
  assert_schema1_pragmas(conn)
  assert_schema2_pragmas(conn)

  let assert Ok(Nil) = sqlight.close(conn)
}
