import case_studies/fruit_db/delete
import case_studies/fruit_db/get
import case_studies/fruit_db/migration
import case_studies/fruit_db/query
import case_studies/fruit_db/upsert
import case_studies/fruit_schema
import gleam/list
import gleam/option
import sqlight
import swil/dsl/dsl

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

pub fn by_fruit_name(
  name name: String,
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> fn(sqlight.Connection) ->
  Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  fn(conn) {
    upsert.upsert_fruit_by_name(
      conn,
      name: name,
      color: color,
      price: price,
      quantity: quantity,
    )
  }
}

pub fn upsert_many_fruit(
  conn: sqlight.Connection,
  rows rows: List(
    fn(sqlight.Connection) ->
      Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error),
  ),
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  list.try_map(rows, fn(row) { row(conn) })
}

pub fn upsert_one_fruit(
  conn: sqlight.Connection,
  row row: fn(sqlight.Connection) ->
    Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  row(conn)
}
