pub type MytrackByName {
  MytrackByName
}

pub type MytrackUpsertRow(by) {
  MytrackUpsertRow(
    run: fn(sqlight.Connection) ->
      Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error),
  )
}

fn run_mytrack_upsert_row(
  row: MytrackUpsertRow(by),
  conn: sqlight.Connection,
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  let MytrackUpsertRow(run:) = row
  run(conn)
}

import case_studies/types_playground_db/delete
import case_studies/types_playground_db/get
import case_studies/types_playground_db/migration
import case_studies/types_playground_db/query
import case_studies/types_playground_db/upsert
import case_studies/types_playground_schema
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/dsl/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn last_100_edited_mytrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_mytrack(conn)
}

pub fn get_mytrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_mytrack_by_id(conn, id: id)
}

pub fn update_mytrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
  name name: option.Option(String),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  upsert.update_mytrack_by_id(
    conn,
    id: id,
    added_to_playlist_at: added_to_playlist_at,
    name: name,
  )
}

pub fn delete_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_mytrack_by_name(conn, name: name)
}

pub fn update_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  upsert.update_mytrack_by_name(
    conn,
    name: name,
    added_to_playlist_at: added_to_playlist_at,
  )
}

pub fn get_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_mytrack_by_name(conn, name: name)
}

pub fn by_mytrack_name(
  name name: String,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
) -> MytrackUpsertRow(MytrackByName) {
  MytrackUpsertRow(fn(conn) {
    upsert.upsert_mytrack_by_name(
      conn,
      name: name,
      added_to_playlist_at: added_to_playlist_at,
    )
  })
}

pub fn upsert_many_mytrack(
  conn: sqlight.Connection,
  rows rows: List(MytrackUpsertRow(by)),
) -> Result(
  List(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(rows, fn(row) { run_mytrack_upsert_row(row, conn) })
}

pub fn upsert_one_mytrack(
  conn: sqlight.Connection,
  row row: MytrackUpsertRow(by),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  run_mytrack_upsert_row(row, conn)
}
