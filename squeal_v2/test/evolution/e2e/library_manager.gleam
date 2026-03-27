import case_studies/library_manager_db/api
import case_studies/library_manager_schema.{ViewConfigScalar}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{Some}
import sqlight

fn insert_tag(
  conn: sqlight.Connection,
  label: String,
  emoji: String,
  now: Int,
) -> Int {
  let assert Ok([id]) =
    sqlight.query(
      "insert into \"tag\" (\"label\", \"emoji\", \"created_at\", \"updated_at\", \"deleted_at\") values (?, ?, ?, ?, null) returning \"id\";",
      on: conn,
      with: [
        sqlight.text(label),
        sqlight.text(emoji),
        sqlight.int(now),
        sqlight.int(now),
      ],
      expecting: {
        use id <- decode.field(0, decode.int)
        decode.success(id)
      },
    )
  id
}

fn insert_trackbucket(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  now: Int,
) -> Int {
  let assert Ok([id]) =
    sqlight.query(
      "insert into \"trackbucket\" (\"title\", \"artist\", \"created_at\", \"updated_at\", \"deleted_at\") values (?, ?, ?, ?, null) returning \"id\";",
      on: conn,
      with: [
        sqlight.text(title),
        sqlight.text(artist),
        sqlight.int(now),
        sqlight.int(now),
      ],
      expecting: {
        use id <- decode.field(0, decode.int)
        decode.success(id)
      },
    )
  id
}

fn insert_tab(
  conn: sqlight.Connection,
  label: String,
  order: Float,
  view_config_json: String,
  now: Int,
) -> Int {
  let assert Ok([id]) =
    sqlight.query(
      "insert into \"tab\" (\"label\", \"order\", \"view_config\", \"created_at\", \"updated_at\", \"deleted_at\") values (?, ?, ?, ?, ?, null) returning \"id\";",
      on: conn,
      with: [
        sqlight.text(label),
        sqlight.float(order),
        sqlight.text(view_config_json),
        sqlight.int(now),
        sqlight.int(now),
      ],
      expecting: {
        use id <- decode.field(0, decode.int)
        decode.success(id)
      },
    )
  id
}

pub fn library_manager_e2e_test() {
  let now = 1_700_000_000
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)

  // ImportedTrack writes through generated API.
  let assert Ok(#(first_track, _first_magic)) =
    api.upsert_importedtrack_by_title_and_artist(
      conn,
      "One More Time",
      "Daft Punk",
      Some("/music/daft/one_more_time.flac"),
    )
  let assert Some("One More Time") = first_track.title
  let assert Some("Daft Punk") = first_track.artist

  let assert Ok(#(_second_track, second_magic)) =
    api.upsert_importedtrack_by_title_and_artist(
      conn,
      "Aerodynamic",
      "Daft Punk",
      Some("/music/daft/aerodynamic.flac"),
    )

  let assert Ok(Some(#(fetched_by_id, _))) =
    api.get_importedtrack_by_id(conn, second_magic.id)
  let assert Some("Aerodynamic") = fetched_by_id.title

  // Tag / TrackBucket / Tab inserts through SQL (write API not generated for all entities yet).
  let tag_id = insert_tag(conn, "Favorite", "star", now)
  let bucket_id = insert_trackbucket(conn, "Daft Punk", "Daft Punk", now)
  let tab_id =
    insert_tab(
      conn,
      "Main",
      1.0,
      "{\"tag\":\"ViewConfigScalar\",\"filter_config\":\"genre:electronic\",\"source_selector\":\"all\"}",
      now,
    )

  let assert Ok(Some(#(tag_row, _))) = api.get_tag_by_id(conn, tag_id)
  let assert Some("Favorite") = tag_row.label

  let assert Ok(Some(#(bucket_row, _))) = api.get_trackbucket_by_id(conn, bucket_id)
  let assert Some("Daft Punk") = bucket_row.title

  let assert Ok(Some(#(tab_row, _))) = api.get_tab_by_id(conn, tab_id)
  let assert Some("Main") = tab_row.label
  let assert Some(ViewConfigScalar(filter_config:, source_selector:)) = tab_row.view_config
  let assert Some("genre:electronic") = filter_config
  let assert Some("all") = source_selector

  // Query coverage (`last_100_*`) for all entities.
  let assert Ok(tag_rows) = api.last_100_edited_tag(conn)
  let assert True = list.length(tag_rows) >= 1

  let assert Ok(bucket_rows) = api.last_100_edited_trackbucket(conn)
  let assert True = list.length(bucket_rows) >= 1

  let assert Ok(tab_rows) = api.last_100_edited_tab(conn)
  let assert True = list.length(tab_rows) >= 1

  let assert Ok(track_rows) = api.last_100_edited_importedtrack(conn)
  let assert True = list.length(track_rows) >= 2

  // Explicit decode failure path for invalid custom-scalar JSON.
  let bad_tab_id = insert_tab(conn, "Broken", 2.0, "not-json", now)
  let assert Error(_) = api.get_tab_by_id(conn, bad_tab_id)

  let assert Ok(Nil) = sqlight.close(conn)
}

