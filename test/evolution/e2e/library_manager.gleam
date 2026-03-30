import case_studies/library_manager_db/api
import case_studies/library_manager_schema.{ViewConfigScalar}
import gleam/list
import gleam/option.{Some}
import sqlight

pub fn library_manager_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)

  // ImportedTrack writes through generated API.
  let assert Ok(#(first_track, _first_magic)) =
    api.upsert_importedtrack_by_title_and_artist(
      conn,
      title: "One More Time",
      artist: "Daft Punk",
      file_path: Some("/music/daft/one_more_time.flac"),
    )
  let assert Some("One More Time") = first_track.title
  let assert Some("Daft Punk") = first_track.artist

  let assert Ok(#(_second_track, second_magic)) =
    api.upsert_importedtrack_by_title_and_artist(
      conn,
      title: "Aerodynamic",
      artist: "Daft Punk",
      file_path: Some("/music/daft/aerodynamic.flac"),
    )

  let assert Ok(Some(#(fetched_by_id, _))) =
    api.get_importedtrack_by_id(conn, id: second_magic.id)
  let assert Some("Aerodynamic") = fetched_by_id.title

  let assert Ok(#(tag_row, tag_magic)) =
    api.upsert_tag_by_tag_label(conn, label: "Favorite", emoji: Some("star"))
  let assert Some("Favorite") = tag_row.label

  let assert Ok(#(bucket_row, bucket_magic)) =
    api.upsert_trackbucket_by_bucket_title_and_artist(
      conn,
      title: "Daft Punk",
      artist: "Daft Punk",
    )
  let assert Some("Daft Punk") = bucket_row.title

  let assert Ok(#(tab_row, tab_magic)) =
    api.upsert_tab_by_tab_label(
      conn,
      label: "Main",
      order: Some(1.0),
      view_config: Some(ViewConfigScalar(
        filter_config: Some("genre:electronic"),
        source_selector: Some("all"),
      )),
    )
  let assert Some("Main") = tab_row.label
  let assert Some(ViewConfigScalar(filter_config:, source_selector:)) =
    tab_row.view_config
  let assert Some("genre:electronic") = filter_config
  let assert Some("all") = source_selector

  let assert Ok(Some(#(fetched_tag, _))) =
    api.get_tag_by_id(conn, id: tag_magic.id)
  let assert Some("Favorite") = fetched_tag.label
  let assert Ok(Some(#(fetched_bucket, _))) =
    api.get_trackbucket_by_id(conn, id: bucket_magic.id)
  let assert Some("Daft Punk") = fetched_bucket.title
  let assert Ok(Some(#(fetched_tab, _))) =
    api.get_tab_by_id(conn, id: tab_magic.id)
  let assert Some("Main") = fetched_tab.label

  // Query coverage (`last_100_*`) for all entities.
  let assert Ok(tag_rows) = api.last_100_edited_tag(conn)
  let assert True = list.length(tag_rows) >= 1

  let assert Ok(bucket_rows) = api.last_100_edited_trackbucket(conn)
  let assert True = list.length(bucket_rows) >= 1

  let assert Ok(tab_rows) = api.last_100_edited_tab(conn)
  let assert True = list.length(tab_rows) >= 1

  let assert Ok(track_rows) = api.last_100_edited_importedtrack(conn)
  let assert True = list.length(track_rows) >= 2

  let assert Ok(Nil) = sqlight.close(conn)
}
