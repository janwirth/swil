//// `ByServiceAndSourceId` index must be dropped before `ALTER TABLE … DROP COLUMN`;
//// v2 adds `added_to_library_at` (`Option(Timestamp)`).
import case_studies/imported_track_evolution_v1_db/api as track_v1
import case_studies/imported_track_evolution_v2_db/api as track_v2
import gleam/option.{None, Some}
import gleam/time/timestamp
import sqlight

pub fn imported_track_v1_to_v2_migration_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = track_v1.migrate(conn)

  let assert Ok(#(row_v1, _)) =
    track_v1.upsert_one_importedtrack(
      conn,
      track_v1.by_importedtrack_service_and_source_id(
        service: "spotify",
        source_id: "track-1",
        title: Some("Song A"),
        artist: Some("Artist A"),
        external_source_url: None,
      ),
    )
  let assert Some("Song A") = row_v1.title

  let assert Ok(Nil) = track_v2.migrate(conn)

  let assert Ok(Some(#(after, _))) =
    track_v2.get_importedtrack_by_service_and_source_id(
      conn,
      service: "spotify",
      source_id: "track-1",
    )
  let assert Some("Song A") = after.title
  let assert True = after.added_to_library_at == None

  let unix = 1_720_000_000
  let ts = timestamp.from_unix_seconds(unix)
  let assert Ok(#(updated, _)) =
    track_v2.upsert_one_importedtrack(
      conn,
      track_v2.by_importedtrack_service_and_source_id(
        service: "spotify",
        source_id: "track-1",
        title: Some("Song A"),
        artist: Some("Artist A"),
        added_to_library_at: Some(ts),
        external_source_url: None,
      ),
    )
  let assert Some(lib_at) = updated.added_to_library_at
  let #(got_sec, _) = timestamp.to_unix_seconds_and_nanoseconds(lib_at)
  let assert True = got_sec == unix

  let assert Ok(Nil) = sqlight.close(conn)
}
