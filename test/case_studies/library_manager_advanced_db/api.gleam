import case_studies/library_manager_advanced_db/cmd
import case_studies/library_manager_advanced_db/get
import case_studies/library_manager_advanced_db/migration
import case_studies/library_manager_advanced_db/query
import case_studies/library_manager_advanced_schema
import gleam/option
import sqlight
import swil/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn query_tracks_by_view_config(
  conn: sqlight.Connection,
  complex_tag_filter_expression complex_tag_filter_expression: library_manager_advanced_schema.FilterExpressionScalar,
) -> Result(
  List(#(library_manager_advanced_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  query.query_tracks_by_view_config(
    conn,
    complex_tag_filter_expression: complex_tag_filter_expression,
  )
}

pub fn last_100_edited_tab(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_advanced_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_tab(conn)
}

pub fn last_100_edited_trackbucket(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_advanced_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_trackbucket(conn)
}

pub fn last_100_edited_tag(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_advanced_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_tag(conn)
}

pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_advanced_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_importedtrack(conn)
}

pub fn get_tab_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_advanced_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tab_by_id(conn, id: id)
}

pub fn get_trackbucket_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_advanced_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_trackbucket_by_id(conn, id: id)
}

pub fn get_tag_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_advanced_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tag_by_id(conn, id: id)
}

pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(
    #(library_manager_advanced_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  get.get_importedtrack_by_id(conn, id: id)
}

pub fn get_tab_by_tab_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(
  option.Option(#(library_manager_advanced_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tab_by_tab_label(conn, label: label)
}

pub fn execute_tab_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.TabCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_tab_cmds(conn, commands)
}

pub fn get_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(
  option.Option(#(library_manager_advanced_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_trackbucket_by_bucket_title_and_artist(
    conn,
    title: title,
    artist: artist,
  )
}

pub fn execute_trackbucket_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.TrackBucketCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_trackbucket_cmds(conn, commands)
}

pub fn get_tag_by_tag_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(
  option.Option(#(library_manager_advanced_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tag_by_tag_label(conn, label: label)
}

pub fn execute_tag_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.TagCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_tag_cmds(conn, commands)
}

pub fn get_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path file_path: String,
) -> Result(
  option.Option(
    #(library_manager_advanced_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  get.get_importedtrack_by_file_path(conn, file_path: file_path)
}

pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(
  option.Option(
    #(library_manager_advanced_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  get.get_importedtrack_by_title_and_artist(conn, title: title, artist: artist)
}

pub fn execute_importedtrack_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.ImportedTrackCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_importedtrack_cmds(conn, commands)
}
