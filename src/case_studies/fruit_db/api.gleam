import case_studies/fruit_db/delete
import case_studies/fruit_db/get
import case_studies/fruit_db/migration
import case_studies/fruit_db/query
import case_studies/fruit_db/upsert
import case_studies/fruit_schema
import gleam/option
import skwil/dsl/dsl
import sqlight

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn query_cheap_fruit(
  conn: sqlight.Connection,
  max_price max_price: Float,
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  query.query_cheap_fruit(conn, max_price: max_price)
}

pub fn last_100_edited_fruit(
  conn: sqlight.Connection,
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_fruit(conn)
}

pub fn get_fruit_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(fruit_schema.Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_fruit_by_id(conn, id: id)
}

pub fn update_fruit_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  upsert.update_fruit_by_id(
    conn,
    id: id,
    name: name,
    color: color,
    price: price,
    quantity: quantity,
  )
}

pub fn delete_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_fruit_by_name(conn, name: name)
}

pub fn update_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  upsert.update_fruit_by_name(
    conn,
    name: name,
    color: color,
    price: price,
    quantity: quantity,
  )
}

pub fn get_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(fruit_schema.Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_fruit_by_name(conn, name: name)
}

pub fn upsert_many_fruit_by_name(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    sqlight.Connection,
    a,
    fn(
      sqlight.Connection,
      String,
      option.Option(String),
      option.Option(Float),
      option.Option(Int),
    ) ->
      Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error),
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  upsert.upsert_many_fruit_by_name(conn, items: items, each: each)
}

pub fn upsert_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_fruit_by_name(
    conn,
    name: name,
    color: color,
    price: price,
    quantity: quantity,
  )
}
