import case_studies/fruit_db/row
import case_studies/fruit_schema
import gleam/option
import gleam/result
import swil/dsl/dsl
import sqlight

const select_fruit_by_id_sql = "select \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"fruit\" where \"id\" = ? and \"deleted_at\" is null;"

const select_fruit_by_name_sql = "select \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"fruit\" where \"name\" = ? and \"deleted_at\" is null;"

/// Get a fruit by row id.
pub fn get_fruit_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(fruit_schema.Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_fruit_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.fruit_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a fruit by the `ByName` identity.
pub fn get_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(fruit_schema.Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_fruit_by_name_sql,
    on: conn,
    with: [sqlight.text(name)],
    expecting: row.fruit_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}
