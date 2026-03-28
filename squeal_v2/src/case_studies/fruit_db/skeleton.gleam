import case_studies/fruit_schema.{type Fruit}
import dsl/dsl
import gleam/option
import sqlight

/// Generated from `case_studies/fruit_schema`.
///
/// Table of contents:
/// - `migrate/1`
/// - Entity ops: Fruit
/// - Query specs: `query_cheap_fruit`
pub fn migrate(_conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  panic as "TODO: generated migration SQL"
}

/// List up to 100 recently edited fruit rows.
pub fn last_100_edited_fruit(
  _conn: sqlight.Connection,
) -> Result(List(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Delete a fruit by the `ByName` identity.
pub fn delete_fruit_by_name(
  _conn: sqlight.Connection,
  _name: String,
) -> Result(Nil, sqlight.Error) {
  panic as "TODO: generated delete SQL"
}

/// Update a fruit by the `ByName` identity.
pub fn update_fruit_by_name(
  _conn: sqlight.Connection,
  _name: String,
  _color: option.Option(String),
  _price: option.Option(Float),
  _quantity: option.Option(Int),
) -> Result(#(Fruit, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated update SQL and decoding"
}

/// Get a fruit by the `ByName` identity.
pub fn get_fruit_by_name(
  _conn: sqlight.Connection,
  _name: String,
) -> Result(option.Option(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Upsert a fruit by the `ByName` identity.
pub fn upsert_fruit_by_name(
  _conn: sqlight.Connection,
  _name: String,
  _color: option.Option(String),
  _price: option.Option(Float),
  _quantity: option.Option(Int),
) -> Result(#(Fruit, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated upsert SQL and decoding"
}

pub type QueryCheapFruitRow {
  QueryCheapFruitRow
}

/// Execute generated query for the `query_cheap_fruit` spec.
pub fn query_cheap_fruit(
  _conn: sqlight.Connection,
  _max_price: Float,
) -> Result(List(QueryCheapFruitRow), sqlight.Error) {
  panic as "TODO: generated select SQL, parameters, and decoder"
}
