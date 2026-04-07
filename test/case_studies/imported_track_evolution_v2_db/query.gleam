import case_studies/imported_track_evolution_v2_db/row
import case_studies/imported_track_evolution_v2_schema
import sqlight
import swil/dsl

const page_edited_importedtrack_sql = "select \"title\", \"artist\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit ? offset ?;"

const last_100_importedtrack_sql = "select \"title\", \"artist\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// List recently edited importedtrack rows with pagination.
pub fn page_edited_importedtrack(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(
  List(#(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    page_edited_importedtrack_sql,
    on: conn,
    with: [sqlight.int(limit), sqlight.int(offset)],
    expecting: row.importedtrack_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited importedtrack rows.
pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(imported_track_evolution_v2_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    last_100_importedtrack_sql,
    on: conn,
    with: [],
    expecting: row.importedtrack_with_magic_row_decoder(),
  )
}
