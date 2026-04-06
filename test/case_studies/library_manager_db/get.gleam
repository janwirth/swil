import case_studies/library_manager_db/row
import case_studies/library_manager_schema
import gleam/option
import sqlight
import swil/dsl/dsl
import swil/runtime/query

const select_tab_by_id_sql = "select \"label\", \"order\", \"view_config\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tab\" where \"id\" = ? and \"deleted_at\" is null;"

const select_tab_by_tab_label_sql = "select \"label\", \"order\", \"view_config\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tab\" where \"label\" = ? and \"deleted_at\" is null;"

const select_trackbucket_by_id_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"id\" = ? and \"deleted_at\" is null;"

const select_trackbucket_by_bucket_title_and_artist_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const select_tag_by_id_sql = "select \"label\", \"emoji\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"id\" = ? and \"deleted_at\" is null;"

const select_tag_by_tag_label_sql = "select \"label\", \"emoji\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"label\" = ? and \"deleted_at\" is null;"

const select_importedtrack_by_id_sql = "select \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"id\" = ? and \"deleted_at\" is null;"

const select_importedtrack_by_file_path_sql = "select \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"file_path\" = ? and \"deleted_at\" is null;"

const select_importedtrack_by_title_and_artist_sql = "select \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

/// Get a tab by row id.
pub fn get_tab_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_tab_by_id_sql, [sqlight.int(id)], row.tab_with_magic_row_decoder())
}

/// Get a tab by the `ByTabLabel` identity.
pub fn get_tab_by_tab_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(
  option.Option(#(library_manager_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_tab_by_tab_label_sql, [sqlight.text(label)], row.tab_with_magic_row_decoder())
}

/// Get a trackbucket by row id.
pub fn get_trackbucket_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_trackbucket_by_id_sql, [sqlight.int(id)], row.trackbucket_with_magic_row_decoder())
}

/// Get a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn get_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(
  option.Option(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(
    conn,
    select_trackbucket_by_bucket_title_and_artist_sql,
    [sqlight.text(title), sqlight.text(artist)],
    row.trackbucket_with_magic_row_decoder(),
  )
}

/// Get a tag by row id.
pub fn get_tag_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_tag_by_id_sql, [sqlight.int(id)], row.tag_with_magic_row_decoder())
}

/// Get a tag by the `ByTagLabel` identity.
pub fn get_tag_by_tag_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(
  option.Option(#(library_manager_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_tag_by_tag_label_sql, [sqlight.text(label)], row.tag_with_magic_row_decoder())
}

/// Get a importedtrack by the `ByFilePath` identity.
pub fn get_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path file_path: String,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_importedtrack_by_file_path_sql, [sqlight.text(file_path)], row.importedtrack_with_magic_row_decoder())
}

/// Get a importedtrack by row id.
pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_importedtrack_by_id_sql, [sqlight.int(id)], row.importedtrack_with_magic_row_decoder())
}

/// Get a importedtrack by the `ByTitleAndArtist` identity.
pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(
    conn,
    select_importedtrack_by_title_and_artist_sql,
    [sqlight.text(title), sqlight.text(artist)],
    row.importedtrack_with_magic_row_decoder(),
  )
}
