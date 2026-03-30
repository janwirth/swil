import case_studies/fruit_db/delete
import case_studies/fruit_db/get
import case_studies/fruit_db/migration
import case_studies/fruit_db/query
import case_studies/fruit_db/upsert
import case_studies/fruit_schema
import skwil/dsl/dsl
import gleam/option
import sqlight

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn query_cheap_fruit(
  conn: sqlight.Connection,
  max_price: Float,
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  query.query_cheap_fruit(conn, max_price)
}

pub fn last_100_edited_fruit(
  conn: sqlight.Connection,
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_fruit(conn)
}

pub fn get_fruit_by_id(
  conn: sqlight.Connection,
  id: Int,
) -> Result(
  option.Option(#(fruit_schema.Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_fruit_by_id(conn, id)
}

pub fn update_fruit_by_id(
  conn: sqlight.Connection,
  id: Int,
  name: option.Option(String),
  color: option.Option(String),
  price: option.Option(Float),
  quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  upsert.update_fruit_by_id(conn, id, name, color, price, quantity)
}

pub fn delete_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_fruit_by_name(conn, name)
}

pub fn update_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: option.Option(String),
  price: option.Option(Float),
  quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  upsert.update_fruit_by_name(conn, name, color, price, quantity)
}

pub fn get_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(
  option.Option(#(fruit_schema.Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_fruit_by_name(conn, name)
}

pub fn upsert_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: option.Option(String),
  price: option.Option(Float),
  quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_fruit_by_name(conn, name, color, price, quantity)
}
