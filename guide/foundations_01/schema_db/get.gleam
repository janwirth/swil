import gleam/option
import gleam/result
import guide/foundations_01/schema
import guide/foundations_01/schema_db/row
import sqlight
import swil/dsl/dsl

const select_guide01item_by_id_sql = "select \"name\", \"note\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"guide01item\" where \"id\" = ? and \"deleted_at\" is null;"

const select_guide01item_by_name_sql = "select \"name\", \"note\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"guide01item\" where \"name\" = ? and \"deleted_at\" is null;"

/// Get a guide01item by row id.
pub fn get_guide01item_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(schema.Guide01Item, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_guide01item_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.guide01item_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a guide01item by the `ByName` identity.
pub fn get_guide01item_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(schema.Guide01Item, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_guide01item_by_name_sql,
    on: conn,
    with: [sqlight.text(name)],
    expecting: row.guide01item_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}
