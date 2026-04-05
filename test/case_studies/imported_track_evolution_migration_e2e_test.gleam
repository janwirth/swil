//// `ByServiceAndSourceId` index must be dropped before `ALTER TABLE … DROP COLUMN`;
//// v2 adds `added_to_library_at` (`Option(Timestamp)`).
import case_studies/imported_track_evolution_v1_db/api as track_v1
import case_studies/imported_track_evolution_v1_db/cmd as track_v1_cmd
import case_studies/imported_track_evolution_v2_db/api as track_v2
import case_studies/imported_track_evolution_v2_db/cmd as track_v2_cmd
import gleam/option.{None, Some}
import gleam/time/timestamp
import sqlight

pub fn imported_track_v1_to_v2_migration_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = track_v1.migrate(conn)

  let assert Ok(Nil) =
    track_v1.execute_importedtrack_cmds(conn, [
      track_v1_cmd.UpsertImportedTrackByServiceAndSourceId(
        service: "spotify",
        source_id: "track-1",
        title: Some("Song A"),
        artist: Some("Artist A"),
        external_source_url: None,
      ),
    ])
  let assert Ok(Some(#(row_v1, _))) =
    track_v1.get_importedtrack_by_service_and_source_id(
      conn,
      service: "spotify",
      source_id: "track-1",
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
  let assert Ok(Nil) =
    track_v2.execute_importedtrack_cmds(conn, [
      track_v2_cmd.UpsertImportedTrackByServiceAndSourceId(
        service: "spotify",
        source_id: "track-1",
        title: Some("Song A"),
        artist: Some("Artist A"),
        added_to_library_at: Some(ts),
        external_source_url: None,
      ),
    ])
  let assert Ok(Some(#(updated, _))) =
    track_v2.get_importedtrack_by_service_and_source_id(
      conn,
      service: "spotify",
      source_id: "track-1",
    )
  let assert Some(lib_at) = updated.added_to_library_at
  let #(got_sec, _) = timestamp.to_unix_seconds_and_nanoseconds(lib_at)
  let assert True = got_sec == unix

  // `last_100_edited_*` must decode nullable text columns (SQL NULL), not only "".
  let assert Ok(Nil) =
    sqlight.exec(
      "update \"importedtrack\" set \"title\" = null, \"artist\" = null where \"service\" = 'spotify';",
      conn,
    )
  let assert Ok(recent) = track_v2.last_100_edited_importedtrack(conn)
  let assert [#(with_nulls, _), ..] = recent
  let assert True = with_nulls.title == None && with_nulls.artist == None

  let assert Ok(Nil) = sqlight.close(conn)
}
