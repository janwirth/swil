pub type ImportedtrackByServiceAndSourceId {
  ImportedtrackByServiceAndSourceId
}

pub type ImportedtrackUpsertRow(by) {
  ImportedtrackUpsertRow(
    run: fn(sqlight.Connection) ->
      Result(
        #(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields),
        sqlight.Error,
      ),
  )
}

fn run_importedtrack_upsert_row(
  row: ImportedtrackUpsertRow(by),
  conn: sqlight.Connection,
) -> Result(
  #(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let ImportedtrackUpsertRow(run:) = row
  run(conn)
}

import case_studies/imported_track_evolution_v2_db/delete
import case_studies/imported_track_evolution_v2_db/get
import case_studies/imported_track_evolution_v2_db/migration
import case_studies/imported_track_evolution_v2_db/query
import case_studies/imported_track_evolution_v2_db/upsert
import case_studies/imported_track_evolution_v2_schema
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/dsl/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_importedtrack(conn)
}

pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(
    #(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  get.get_importedtrack_by_id(conn, id: id)
}

pub fn update_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
  title title: option.Option(String),
  artist artist: option.Option(String),
  service service: option.Option(String),
  source_id source_id: option.Option(String),
  added_to_library_at added_to_library_at: option.Option(Timestamp),
  external_source_url external_source_url: option.Option(String),
) -> Result(
  #(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_importedtrack_by_id(
    conn,
    id: id,
    title: title,
    artist: artist,
    service: service,
    source_id: source_id,
    added_to_library_at: added_to_library_at,
    external_source_url: external_source_url,
  )
}

pub fn delete_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_importedtrack_by_service_and_source_id(
    conn,
    service: service,
    source_id: source_id,
  )
}

pub fn update_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
  title title: option.Option(String),
  artist artist: option.Option(String),
  added_to_library_at added_to_library_at: option.Option(Timestamp),
  external_source_url external_source_url: option.Option(String),
) -> Result(
  #(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_importedtrack_by_service_and_source_id(
    conn,
    service: service,
    source_id: source_id,
    title: title,
    artist: artist,
    added_to_library_at: added_to_library_at,
    external_source_url: external_source_url,
  )
}

pub fn get_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
) -> Result(
  option.Option(
    #(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  get.get_importedtrack_by_service_and_source_id(
    conn,
    service: service,
    source_id: source_id,
  )
}

pub fn by_importedtrack_service_and_source_id(
  service service: String,
  source_id source_id: String,
  title title: option.Option(String),
  artist artist: option.Option(String),
  added_to_library_at added_to_library_at: option.Option(Timestamp),
  external_source_url external_source_url: option.Option(String),
) -> ImportedtrackUpsertRow(ImportedtrackByServiceAndSourceId) {
  ImportedtrackUpsertRow(fn(conn) {
    upsert.upsert_importedtrack_by_service_and_source_id(
      conn,
      service: service,
      source_id: source_id,
      title: title,
      artist: artist,
      added_to_library_at: added_to_library_at,
      external_source_url: external_source_url,
    )
  })
}

pub fn upsert_many_importedtrack(
  conn: sqlight.Connection,
  rows rows: List(ImportedtrackUpsertRow(by)),
) -> Result(
  List(#(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(rows, fn(row) { run_importedtrack_upsert_row(row, conn) })
}

pub fn upsert_one_importedtrack(
  conn: sqlight.Connection,
  row row: ImportedtrackUpsertRow(by),
) -> Result(
  #(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  run_importedtrack_upsert_row(row, conn)
}
