import from_usage/one/tuna_db/row.{
  type ImportedTrackRow, type TagRow, type TrackBucketRow,
}
import from_usage/one/tuna_schema
import sqlight
import swil/dsl

const track_by_source_root_sql = "select \"from_source_root\", \"title\", \"artist\", \"file_path\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"deleted_at\" is null and \"from_source_root\" = ? order by \"added_to_library_at\" desc;"

const page_edited_tag_sql = "select \"label\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"deleted_at\" is null order by \"updated_at\" desc limit ? offset ?;"

const last_100_tag_sql = "select \"label\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

const page_edited_trackbucket_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"deleted_at\" is null order by \"updated_at\" desc limit ? offset ?;"

const last_100_trackbucket_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

const page_edited_importedtrack_sql = "select \"from_source_root\", \"title\", \"artist\", \"file_path\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit ? offset ?;"

const last_100_importedtrack_sql = "select \"from_source_root\", \"title\", \"artist\", \"file_path\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

pub fn query_track_by_source_root(
  conn: sqlight.Connection,
  source_root source_root: String,
) -> Result(List(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    track_by_source_root_sql,
    on: conn,
    with: [sqlight.text(source_root)],
    expecting: row.importedtrack_with_magic_row_decoder(),
  )
}

/// List recently edited tag rows with pagination.
pub fn page_edited_tag(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(TagRow, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    page_edited_tag_sql,
    on: conn,
    with: [sqlight.int(limit), sqlight.int(offset)],
    expecting: row.tag_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited tag rows.
pub fn last_100_edited_tag(
  conn: sqlight.Connection,
) -> Result(List(#(TagRow, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_tag_sql,
    on: conn,
    with: [],
    expecting: row.tag_with_magic_row_decoder(),
  )
}

/// List recently edited trackbucket rows with pagination.
pub fn page_edited_trackbucket(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(TrackBucketRow, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    page_edited_trackbucket_sql,
    on: conn,
    with: [sqlight.int(limit), sqlight.int(offset)],
    expecting: row.trackbucket_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited trackbucket rows.
pub fn last_100_edited_trackbucket(
  conn: sqlight.Connection,
) -> Result(List(#(TrackBucketRow, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_trackbucket_sql,
    on: conn,
    with: [],
    expecting: row.trackbucket_with_magic_row_decoder(),
  )
}

/// List recently edited importedtrack rows with pagination.
pub fn page_edited_importedtrack(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
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
) -> Result(List(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_importedtrack_sql,
    on: conn,
    with: [],
    expecting: row.importedtrack_with_magic_row_decoder(),
  )
}
