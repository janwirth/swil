import case_studies/fruit_db/row
import case_studies/fruit_schema
import gleam/list
import gleam/option
import gleam/result
import sqlight
import swil/api_help
import swil/dsl/dsl

const update_fruit_by_id_sql = "update \"fruit\" set \"name\" = ?, \"color\" = ?, \"price\" = ?, \"quantity\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"name\", \"color\", \"price\", \"quantity\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

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

/// Update a fruit by row id (all scalar columns, including natural-key fields).
pub fn update_fruit_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_name = api_help.opt_text_for_db(name)
  let db_color = api_help.opt_text_for_db(color)
  let db_price = api_help.opt_float_for_db(price)
  let db_quantity = api_help.opt_int_for_db(quantity)
  use rows <- result.try(sqlight.query(
    update_fruit_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_name),
      sqlight.text(db_color),
      sqlight.float(db_price),
      sqlight.int(db_quantity),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.fruit_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_fruit_id_error("update_fruit_by_id"))
  }
}

fn not_found_fruit_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "fruit" <> " not found: " <> op,
    -1,
  )
}

/// Upsert many fruit rows by the `ByName` identity (one SQL upsert per item).
/// Pass the single-row `upsert_fruit_by_name` as the last argument to `each` and call it with labelled fields from `item`.
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
  list.try_map(items, fn(item) { each(conn, item, upsert_fruit_by_name) })
}

/// Update a fruit by the `ByName` identity.
pub fn update_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_color = api_help.opt_text_for_db(color)
  let db_price = api_help.opt_float_for_db(price)
  let db_quantity = api_help.opt_int_for_db(quantity)
  use rows <- result.try(sqlight.query(
    update_fruit_by_name_sql,
    on: conn,
    with: [
      sqlight.text(db_color),
      sqlight.float(db_price),
      sqlight.int(db_quantity),
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
  name name: String,
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_color = api_help.opt_text_for_db(color)
  let db_price = api_help.opt_float_for_db(price)
  let db_quantity = api_help.opt_int_for_db(quantity)
  use rows <- result.try(sqlight.query(
    upsert_fruit_by_name_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.text(db_color),
      sqlight.float(db_price),
      sqlight.int(db_quantity),
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
    "fruit" <> " not found: " <> op,
    -1,
  )
}
