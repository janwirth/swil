import api_help
import dsl/dsl as dsl
import case_studies/fruit_db/row
import case_studies/fruit_schema.{type Fruit, ByName, Fruit}
import gleam/option.{type Option, None, Some}
import gleam/result
import sqlight

const select_by_id_sql = "select \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"fruit\" where \"id\" = ? and \"deleted_at\" is null;"

const select_by_name_sql = "select \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"fruit\" where \"name\" = ? and \"deleted_at\" is null;"

/// Get a fruit by row id.
pub fn by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.fruit_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}

/// Get a fruit by the `ByName` identity.
pub fn get_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(Option(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_by_name_sql,
    on: conn,
    with: [sqlight.text(name)],
    expecting: row.fruit_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}
