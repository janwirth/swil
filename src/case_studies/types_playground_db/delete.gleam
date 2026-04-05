import case_studies/types_playground_db/cmd
import case_studies/types_playground_db/get
import gleam/option
import gleam/result
import sqlight

/// Delete a mytrack by the `ByName` identity.
pub fn delete_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(Nil, sqlight.Error) {
  use existing <- result.try(get.get_mytrack_by_name(conn, name: name))
  case existing {
    option.None -> Error(not_found_mytrack_name_error("delete_mytrack_by_name"))
    option.Some(_) -> {
      case
        cmd.execute_mytrack_cmds(conn, [cmd.DeleteMyTrackByName(name: name)])
      {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
  }
}

fn not_found_mytrack_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "mytrack" <> " not found: " <> op,
    -1,
  )
}
