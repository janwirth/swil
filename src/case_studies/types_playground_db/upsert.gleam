import case_studies/types_playground_db/row
import case_studies/types_playground_schema
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/api_help
import swil/dsl/dsl

const update_mytrack_by_id_sql = "update \"mytrack\" set \"added_to_playlist_at\" = ?, \"name\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"added_to_playlist_at\", \"name\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_mytrack_by_name_sql = "update \"mytrack\" set \"added_to_playlist_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null returning \"added_to_playlist_at\", \"name\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_mytrack_by_name_sql = "insert into \"mytrack\" (\"added_to_playlist_at\", \"name\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"added_to_playlist_at\" = excluded.\"added_to_playlist_at\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"added_to_playlist_at\", \"name\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

/// Update a mytrack by row id (all scalar columns, including natural-key fields).
pub fn update_mytrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
  name name: option.Option(String),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_added_to_playlist_at =
    api_help.opt_timestamp_for_db(added_to_playlist_at)
  let db_name = api_help.opt_text_for_db(name)
  use rows <- result.try(sqlight.query(
    update_mytrack_by_id_sql,
    on: conn,
    with: [
      sqlight.int(db_added_to_playlist_at),
      sqlight.text(db_name),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.mytrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_mytrack_id_error("update_mytrack_by_id"))
  }
}

fn not_found_mytrack_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "mytrack" <> " not found: " <> op,
    -1,
  )
}

/// Upsert many mytrack rows by the `ByName` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_mytrack_by_name`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_mytrack_by_name(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, option.Option(Timestamp)) ->
      Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error),
) -> Result(
  List(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(
      name: String,
      added_to_playlist_at: option.Option(Timestamp),
    ) {
      upsert_mytrack_by_name(
        conn,
        name: name,
        added_to_playlist_at: added_to_playlist_at,
      )
    }
    each(item, upsert_row)
  })
}

/// Update a mytrack by the `ByName` identity.
pub fn update_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_added_to_playlist_at =
    api_help.opt_timestamp_for_db(added_to_playlist_at)
  use rows <- result.try(sqlight.query(
    update_mytrack_by_name_sql,
    on: conn,
    with: [
      sqlight.int(db_added_to_playlist_at),
      sqlight.int(now),
      sqlight.text(name),
    ],
    expecting: row.mytrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_mytrack_name_error("update_mytrack_by_name"))
  }
}

/// Upsert a mytrack by the `ByName` identity.
pub fn upsert_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_added_to_playlist_at =
    api_help.opt_timestamp_for_db(added_to_playlist_at)
  use rows <- result.try(sqlight.query(
    upsert_mytrack_by_name_sql,
    on: conn,
    with: [
      sqlight.int(db_added_to_playlist_at),
      sqlight.text(name),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.mytrack_with_magic_row_decoder(),
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

fn not_found_mytrack_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "mytrack" <> " not found: " <> op,
    -1,
  )
}
