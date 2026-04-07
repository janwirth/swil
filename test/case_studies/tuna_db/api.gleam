import case_studies/tuna_db/cmd
import case_studies/tuna_db/get
import case_studies/tuna_db/migration
import case_studies/tuna_db/query
import case_studies/tuna_db/row.{type ImportedTrackRow, type TagRow, type TrackBucketRow}
import case_studies/tuna_schema
import gleam/option
import sqlight
import swil/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn query_track_by_source_root(
  conn: sqlight.Connection,
  source_root source_root: String,
) -> Result(List(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  query.query_track_by_source_root(conn, source_root: source_root)
}

pub fn page_edited_tag(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(TagRow, dsl.MagicFields)), sqlight.Error) {
  query.page_edited_tag(conn, limit: limit, offset: offset)
}

pub fn page_edited_trackbucket(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(TrackBucketRow, dsl.MagicFields)), sqlight.Error) {
  query.page_edited_trackbucket(conn, limit: limit, offset: offset)
}

pub fn page_edited_importedtrack(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  query.page_edited_importedtrack(conn, limit: limit, offset: offset)
}

pub fn last_100_edited_tag(
  conn: sqlight.Connection,
) -> Result(List(#(TagRow, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_tag(conn)
}

pub fn last_100_edited_trackbucket(
  conn: sqlight.Connection,
) -> Result(List(#(TrackBucketRow, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_trackbucket(conn)
}

pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(List(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_importedtrack(conn)
}

pub fn get_tag_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(option.Option(#(TagRow, dsl.MagicFields)), sqlight.Error) {
  get.get_tag_by_id(conn, id: id)
}

pub fn get_trackbucket_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(option.Option(#(TrackBucketRow, dsl.MagicFields)), sqlight.Error) {
  get.get_trackbucket_by_id(conn, id: id)
}

pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(option.Option(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  get.get_importedtrack_by_id(conn, id: id)
}

pub fn get_tag_by_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(option.Option(#(TagRow, dsl.MagicFields)), sqlight.Error) {
  get.get_tag_by_label(conn, label: label)
}

pub fn execute_tag_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.TagCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_tag_cmds(conn, commands)
}

pub fn get_trackbucket_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(option.Option(#(TrackBucketRow, dsl.MagicFields)), sqlight.Error) {
  get.get_trackbucket_by_title_and_artist(conn, title: title, artist: artist)
}

pub fn execute_trackbucket_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.TrackBucketCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_trackbucket_cmds(conn, commands)
}

pub fn get_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  from_source_root from_source_root: String,
  service service: String,
  source_id source_id: String,
) -> Result(option.Option(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  get.get_importedtrack_by_service_and_source_id(
    conn,
    from_source_root: from_source_root,
    service: service,
    source_id: source_id,
  )
}

pub fn execute_importedtrack_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.ImportedTrackCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_importedtrack_cmds(conn, commands)
}
