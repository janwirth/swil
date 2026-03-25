import gleeunit
import gleam/dynamic/decode
import gleam/int
import gleam/list
import generator.{generate, parse}
import simplifile
import sqlight

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"

  assert greeting == "Hello, Joe!"
}

pub fn hippo_skeleton_generation_test() {
  let assert Ok(schema_source) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(expected_skeleton) =
    simplifile.read("src/case_studies/hippo_db_skeleton.gleam")

  let generated_skeleton = schema_source |> parse |> generate(True)

  assert generated_skeleton == expected_skeleton
}

pub fn hippo_insert_and_read_roundtrip_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = create_hippos_table(conn)
  let assert Ok(Nil) = insert_plain_hippo(conn, "Nubi")

  let assert Ok(rows) = read_all_plain_hippos(conn)
  let assert [#(1, "Nubi")] = rows
}

pub fn hippo_insert_two_and_read_sorted_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = create_hippos_table(conn)
  let assert Ok(Nil) = insert_plain_hippo(conn, "Luna")
  let assert Ok(Nil) = insert_plain_hippo(conn, "Biffy")

  let assert Ok(rows) = read_all_plain_hippos(conn)
  let sorted = list.sort(rows, by: fn(a, b) { int.compare(a.0, b.0) })
  let assert [#(1, "Luna"), #(2, "Biffy")] = sorted
}

fn create_hippos_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  sqlight.exec(
    "create table hippos (id integer primary key autoincrement, name text not null);",
    conn,
  )
}

fn insert_plain_hippo(
  conn: sqlight.Connection,
  name: String,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "insert into hippos (name) values (?);",
    conn,
    with: [sqlight.Text(name)],
    expecting: decode.null(Nil),
  )
  |> result.map(fn(_) { Nil })
}

fn read_all_plain_hippos(
  conn: sqlight.Connection,
) -> Result(List(#(Int, String)), sqlight.Error) {
  sqlight.query(
    "select id, name from hippos order by id asc;",
    conn,
    with: [],
    expecting: hippo_row_decoder(),
  )
}

fn hippo_row_decoder() -> decode.Decoder(#(Int, String)) {
  use id <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  decode.success(#(id, name))
}
