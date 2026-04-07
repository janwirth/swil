import case_studies/types_playground_db/row
import case_studies/types_playground_schema
import sqlight
import swil/dsl

const page_edited_mytrack_sql = "select \"added_to_playlist_at\", \"name\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"mytrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit ? offset ?;"

const last_100_mytrack_sql = "select \"added_to_playlist_at\", \"name\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"mytrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// List recently edited mytrack rows with pagination.
pub fn page_edited_mytrack(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(
  List(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    page_edited_mytrack_sql,
    on: conn,
    with: [sqlight.int(limit), sqlight.int(offset)],
    expecting: row.mytrack_with_magic_row_decoder(),
  )
}

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
