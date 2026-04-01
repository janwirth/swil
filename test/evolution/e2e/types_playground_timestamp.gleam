import case_studies/types_playground_db/api
import gleam/option.{None, Some}
import gleam/time/timestamp
import sqlight

pub fn types_playground_timestamp_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)

  let unix = 1_704_000_000
  let t = timestamp.from_unix_seconds(unix)
  let assert Ok(#(track, _magic)) =
    api.upsert_one_mytrack(
      conn,
      row: api.by_mytrack_name(
        name: "Round Trip",
        added_to_playlist_at: Some(t),
      ),
    )
  let assert Some(playlist_at) = track.added_to_playlist_at
  let #(got, _) = timestamp.to_unix_seconds_and_nanoseconds(playlist_at)
  let assert True = got == unix

  let assert Ok(#(no_ts, _magic2)) =
    api.upsert_one_mytrack(
      conn,
      row: api.by_mytrack_name(
        name: "No Timestamp",
        added_to_playlist_at: None,
      ),
    )
  let assert None = no_ts.added_to_playlist_at

  let assert Ok(Nil) = sqlight.close(conn)
}
