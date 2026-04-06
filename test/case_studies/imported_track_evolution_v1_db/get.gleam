import case_studies/imported_track_evolution_v1_db/row
import case_studies/imported_track_evolution_v1_schema
import gleam/option
import gleam/result
import sqlight
import swil/dsl

const select_importedtrack_by_id_sql = "select \"title\", \"artist\", \"service\", \"source_id\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"id\" = ? and \"deleted_at\" is null;"

const select_importedtrack_by_service_and_source_id_sql = "select \"title\", \"artist\", \"service\", \"source_id\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"

/// Get a importedtrack by row id.
pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(
    #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_importedtrack_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a importedtrack by the `ByServiceAndSourceId` identity.
pub fn get_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
) -> Result(
  option.Option(
    #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_importedtrack_by_service_and_source_id_sql,
    on: conn,
    with: [
      sqlight.text(service),
      sqlight.text(source_id),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}
