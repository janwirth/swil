import case_studies/types_playground_db/row
import case_studies/types_playground_schema
import gleam/option
import sqlight
import swil/dsl/dsl
import swil/runtime/query

const select_mytrack_by_id_sql = "select \"added_to_playlist_at\", \"name\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"mytrack\" where \"id\" = ? and \"deleted_at\" is null;"

const select_mytrack_by_name_sql = "select \"added_to_playlist_at\", \"name\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"mytrack\" where \"name\" = ? and \"deleted_at\" is null;"

/// Get a mytrack by row id.
pub fn get_mytrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_mytrack_by_id_sql, [sqlight.int(id)], row.mytrack_with_magic_row_decoder())
}

/// Get a mytrack by the `ByName` identity.
pub fn get_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_mytrack_by_name_sql, [sqlight.text(name)], row.mytrack_with_magic_row_decoder())
}
