import case_studies/types_playground_db/row
import case_studies/types_playground_schema
import sqlight
import swil/dsl/dsl

const last_100_mytrack_sql = "select \"added_to_playlist_at\", \"name\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"mytrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// List up to 100 recently edited mytrack rows.
pub fn last_100_edited_mytrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    last_100_mytrack_sql,
    on: conn,
    with: [],
    expecting: row.mytrack_with_magic_row_decoder(),
  )
}
