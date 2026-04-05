import case_studies/imported_track_evolution_v1_db/cmd
import case_studies/imported_track_evolution_v1_db/get
import gleam/option
import gleam/result
import sqlight

/// Delete a importedtrack by the `ByServiceAndSourceId` identity.
pub fn delete_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
) -> Result(Nil, sqlight.Error) {
  use existing <- result.try(get.get_importedtrack_by_service_and_source_id(
    conn,
    service: service,
    source_id: source_id,
  ))
  case existing {
    option.None ->
      Error(not_found_importedtrack_service_and_source_id_error(
        "delete_importedtrack_by_service_and_source_id",
      ))
    option.Some(_) -> {
      case
        cmd.execute_importedtrack_cmds(conn, [
          cmd.DeleteImportedTrackByServiceAndSourceId(
            service: service,
            source_id: source_id,
          ),
        ])
      {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
  }
}

fn not_found_importedtrack_service_and_source_id_error(
  op: String,
) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}
