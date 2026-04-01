import gleam/list
import gleam/option
import gleam/result
import guide/foundations_01/schema
import guide/foundations_01/schema_db/row
import sqlight
import swil/api_help
import swil/dsl/dsl

const update_guide01item_by_id_sql = "update \"guide01item\" set \"name\" = ?, \"note\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"name\", \"note\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_guide01item_by_name_sql = "update \"guide01item\" set \"note\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null returning \"name\", \"note\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_guide01item_by_name_sql = "insert into \"guide01item\" (\"name\", \"note\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"note\" = excluded.\"note\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"name\", \"note\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

/// Update a guide01item by row id (all scalar columns, including natural-key fields).
pub fn update_guide01item_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  note note: option.Option(String),
) -> Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_name = api_help.opt_text_for_db(name)
  let db_note = api_help.opt_text_for_db(note)
  use rows <- result.try(sqlight.query(
    update_guide01item_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_name),
      sqlight.text(db_note),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.guide01item_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_guide01item_id_error("update_guide01item_by_id"))
  }
}

fn not_found_guide01item_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "guide01item" <> " not found: " <> op,
    -1,
  )
}

/// Upsert many guide01item rows by the `ByName` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_guide01item_by_name`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_guide01item_by_name(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, option.Option(String)) ->
      Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error),
) -> Result(List(#(schema.Guide01Item, dsl.MagicFields)), sqlight.Error) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(name: String, note: option.Option(String)) {
      upsert_guide01item_by_name(conn, name: name, note: note)
    }
    each(item, upsert_row)
  })
}

/// Update a guide01item by the `ByName` identity.
pub fn update_guide01item_by_name(
  conn: sqlight.Connection,
  name name: String,
  note note: option.Option(String),
) -> Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_note = api_help.opt_text_for_db(note)
  use rows <- result.try(sqlight.query(
    update_guide01item_by_name_sql,
    on: conn,
    with: [
      sqlight.text(db_note),
      sqlight.int(now),
      sqlight.text(name),
    ],
    expecting: row.guide01item_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_guide01item_name_error("update_guide01item_by_name"))
  }
}

/// Upsert a guide01item by the `ByName` identity.
pub fn upsert_guide01item_by_name(
  conn: sqlight.Connection,
  name name: String,
  note note: option.Option(String),
) -> Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_note = api_help.opt_text_for_db(note)
  use rows <- result.try(sqlight.query(
    upsert_guide01item_by_name_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.text(db_note),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.guide01item_with_magic_row_decoder(),
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

fn not_found_guide01item_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "guide01item" <> " not found: " <> op,
    -1,
  )
}
