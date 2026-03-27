import api_help
import dsl/dsl as dsl
import case_studies/fruit_db/row
import case_studies/fruit_schema.{type Fruit, Fruit, ByName}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import sqlight

const update_fruit_by_name_sql = "update \"fruit\" set \"color\" = ?, \"price\" = ?, \"quantity\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null returning \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_fruit_by_name_sql = "insert into \"fruit\" (\"name\", \"color\", \"price\", \"quantity\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"color\" = excluded.\"color\",
  \"price\" = excluded.\"price\",
  \"quantity\" = excluded.\"quantity\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

/// Update a fruit by the `ByName` identity.
pub fn update_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: Option(String),
  price: Option(Float),
  quantity: Option(Int),
) -> Result(#(Fruit, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let c = api_help.opt_text_for_db(color)
  let p = api_help.opt_float_for_db(price)
  let q = api_help.opt_int_for_db(quantity)
  use rows <- result.try(sqlight.query(
    update_fruit_by_name_sql,
    on: conn,
    with: [
      sqlight.text(c),
      sqlight.float(p),
      sqlight.int(q),
      sqlight.int(now),
      sqlight.text(name),
    ],
    expecting: row.fruit_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_fruit_name_error("update_fruit_by_name"))
  }
}

/// Upsert a fruit by the `ByName` identity.
pub fn upsert_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: Option(String),
  price: Option(Float),
  quantity: Option(Int),
) -> Result(#(Fruit, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let c = api_help.opt_text_for_db(color)
  let p = api_help.opt_float_for_db(price)
  let q = api_help.opt_int_for_db(quantity)
  use rows <- result.try(sqlight.query(
    upsert_fruit_by_name_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.text(c),
      sqlight.float(p),
      sqlight.int(q),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.fruit_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

fn not_found_fruit_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "fruit"
    <>
    " not found: "
    <>
    op,
    -1,
  )
}
