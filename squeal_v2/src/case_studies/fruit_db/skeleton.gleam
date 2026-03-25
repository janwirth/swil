import case_studies/fruit_schema.{type Fruit}
import dsl
import gleam/option
import sqlight

/// Generated from `case_studies/fruit_schema`.
///
/// Table of contents:
/// - `migrate/1`
/// - Entity ops: Fruit
/// - Query specs: none
pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated migration SQL"
}

/// Upsert a fruit by the `ByName` identity.
pub fn upsert_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: option.Option(String),
  price: option.Option(Float),
  quantity: option.Option(Int),
) -> Result(#(Fruit, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// Get a fruit by the `ByName` identity.
pub fn get_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(option.Option(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Update a fruit by the `ByName` identity.
pub fn update_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: option.Option(String),
  price: option.Option(Float),
  quantity: option.Option(Int),
) -> Result(#(Fruit, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Delete a fruit by the `ByName` identity.
pub fn delete_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// List up to 100 recently edited fruit rows.
pub fn last_100_edited_fruit(
  conn: sqlight.Connection,
) -> Result(List(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}
