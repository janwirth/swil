import case_studies/types_playground_db/cmd
import case_studies/types_playground_db/get
import case_studies/types_playground_db/migration
import case_studies/types_playground_db/query
import case_studies/types_playground_schema
import gleam/option
import sqlight
import swil/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn page_edited_mytrack(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(
  List(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.page_edited_mytrack(conn, limit: limit, offset: offset)
}

pub fn last_100_edited_mytrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_mytrack(conn)
}

pub fn get_mytrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_mytrack_by_id(conn, id: id)
}

pub fn get_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_mytrack_by_name(conn, name: name)
}

pub fn execute_mytrack_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.MyTrackCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_mytrack_cmds(conn, commands)
}
