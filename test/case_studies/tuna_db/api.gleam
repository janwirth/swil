import case_studies/tuna_db/cmd
import case_studies/tuna_db/get
import case_studies/tuna_db/migration
import case_studies/tuna_db/query
import case_studies/tuna_db/row
import case_studies/tuna_schema
import gleam/option
import sqlight
import swil/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn query_track_title_by_source_root(
  conn: sqlight.Connection,
  source_root source_root: String,
) -> Result(List(row.QueryTrackTitleBySourceRootOutput), sqlight.Error) {
  query.query_track_title_by_source_root(conn, source_root: source_root)
}

pub fn query_track_by_source_root(
  conn: sqlight.Connection,
  source_root source_root: String,
) -> Result(List(#(tuna_schema.ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  query.query_track_by_source_root(conn, source_root: source_root)
}

pub fn page_edited_tag(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(tuna_schema.Tag, dsl.MagicFields)), sqlight.Error) {
  query.page_edited_tag(conn, limit: limit, offset: offset)
}

pub fn page_edited_importedtrack(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(tuna_schema.ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  query.page_edited_importedtrack(conn, limit: limit, offset: offset)
}

pub fn last_100_edited_tag(
  conn: sqlight.Connection,
) -> Result(List(#(tuna_schema.Tag, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_tag(conn)
}

pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(List(#(tuna_schema.ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_importedtrack(conn)
}

pub fn get_tag_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(option.Option(#(tuna_schema.Tag, dsl.MagicFields)), sqlight.Error) {
  get.get_tag_by_id(conn, id: id)
}

pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(tuna_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_importedtrack_by_id(conn, id: id)
}

pub fn get_tag_by_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(option.Option(#(tuna_schema.Tag, dsl.MagicFields)), sqlight.Error) {
  get.get_tag_by_label(conn, label: label)
}

pub fn execute_tag_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.TagCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_tag_cmds(conn, commands)
}

pub fn get_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  from_source_root from_source_root: String,
  service service: String,
  source_id source_id: String,
) -> Result(
  option.Option(#(tuna_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
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
