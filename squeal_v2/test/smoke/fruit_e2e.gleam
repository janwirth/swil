import gleam/string
import case_studies/fruit_db/migration
import case_studies/fruit_db/api
import sqlight
import case_studies/fruit_schema.{type Fruit}
import gleam/option.{type Option, Some}
import gleam/io

pub fn fruit_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)
  let assert Ok(_) = api.upsert_fruit_by_name(conn, "apple", Some("red"), Some(1.0), Some(1))
  io.println("apple upserted")
  let assert Ok(Some(apple)) = api.get_fruit_by_name(conn, "apple")
  io.println("apple: " <> string.inspect(apple))
  let assert Ok(Nil) = sqlight.close(conn)
}