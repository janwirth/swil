import case_studies/additive_item_v1_db/row
import case_studies/additive_item_v1_schema
import gleam/list
import gleam/option
import gleam/result
import sqlight
import swil/api_help
import swil/dsl/dsl

const update_item_by_id_sql = "update \"item\" set \"name\" = ?, \"age\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"name\", \"age\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_item_by_name_and_age_sql = "update \"item\" set \"updated_at\" = ? where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null returning \"name\", \"age\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_item_by_name_and_age_sql = "insert into \"item\" (\"name\", \"age\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"name\", \"age\") do update set
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"name\", \"age\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

/// Update a item by row id (all scalar columns, including natural-key fields).
pub fn update_item_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  age age: option.Option(Int),
) -> Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_name = api_help.opt_text_for_db(name)
  let db_age = api_help.opt_int_for_db(age)
  use rows <- result.try(sqlight.query(
    update_item_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_name),
      sqlight.int(db_age),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.item_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_item_id_error("update_item_by_id"))
  }
}

fn not_found_item_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "item" <> " not found: " <> op, -1)
}

/// Upsert many item rows by the `ByNameAndAge` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_item_by_name_and_age`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_item_by_name_and_age(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, Int) ->
      Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error),
) -> Result(
  List(#(additive_item_v1_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(name: String, age: Int) {
      upsert_item_by_name_and_age(conn, name: name, age: age)
    }
    each(item, upsert_row)
  })
}

/// Update a item by the `ByNameAndAge` identity.
pub fn update_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
) -> Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    update_item_by_name_and_age_sql,
    on: conn,
    with: [
      sqlight.int(now),
      sqlight.text(name),
      sqlight.int(age),
    ],
    expecting: row.item_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(not_found_item_name_and_age_error("update_item_by_name_and_age"))
  }
}

/// Upsert a item by the `ByNameAndAge` identity.
pub fn upsert_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
) -> Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    upsert_item_by_name_and_age_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.int(age),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.item_with_magic_row_decoder(),
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

fn not_found_item_name_and_age_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "item" <> " not found: " <> op, -1)
}
