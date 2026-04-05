import case_studies/fruit_db/cmd
import case_studies/fruit_db/get
import gleam/option
import gleam/result
import sqlight

/// Delete a fruit by the `ByName` identity.
pub fn delete_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(Nil, sqlight.Error) {
  use existing <- result.try(get.get_fruit_by_name(conn, name: name))
  case existing {
    option.None -> Error(not_found_fruit_name_error("delete_fruit_by_name"))
    option.Some(_) -> {
      case cmd.execute_fruit_cmds(conn, [cmd.DeleteFruitByName(name: name)]) {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
  }
}

fn not_found_fruit_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "fruit" <> " not found: " <> op,
    -1,
  )
}
