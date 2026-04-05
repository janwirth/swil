import case_studies/imported_track_evolution_v1_db/cmd
import case_studies/imported_track_evolution_v1_db/get
import case_studies/imported_track_evolution_v1_db/migration
import case_studies/imported_track_evolution_v1_db/query
import case_studies/imported_track_evolution_v1_schema
import gleam/option
import sqlight
import swil/dsl/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_importedtrack(conn)
}

pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(
    #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  get.get_importedtrack_by_id(conn, id: id)
}

pub fn get_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
) -> Result(
  option.Option(
    #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
  ),
  sqlight.Error,
) {
  get.get_importedtrack_by_service_and_source_id(
    conn,
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
