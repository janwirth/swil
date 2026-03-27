import case_studies/fruit_db/row
import dsl/dsl as dsl
import case_studies/fruit_schema.{type Fruit, Fruit, ByName}
import gleam/result
import sqlight

const cheap_fruit_sql = "select \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"fruit\" where \"deleted_at\" is null and \"price\" < ? order by \"price\" asc;"

const last_100_sql = "select \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"fruit\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// `price < max_price`, ordered ascending by `price` (from `query_cheap_fruit` query spec).
pub fn query_cheap_fruit(
  conn: sqlight.Connection,
  max_price: Float,
) -> Result(List(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    cheap_fruit_sql,
    on: conn,
    with: [sqlight.float(max_price)],
    expecting: row.fruit_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited fruit rows.
pub fn last_100_edited_fruit(
  conn: sqlight.Connection,
) -> Result(List(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_sql,
    on: conn,
    with: [],
    expecting: row.fruit_with_magic_row_decoder(),
  )
}
