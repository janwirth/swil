import case_studies/additive_item_v1_db/cmd
import case_studies/additive_item_v1_db/get
import gleam/option
import gleam/result
import sqlight

/// Delete a item by the `ByNameAndAge` identity.
pub fn delete_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
) -> Result(Nil, sqlight.Error) {
  use existing <- result.try(get.get_item_by_name_and_age(
    conn,
    name: name,
    age: age,
  ))
  case existing {
    option.None ->
      Error(not_found_item_name_and_age_error("delete_item_by_name_and_age"))
    option.Some(_) -> {
      case
        cmd.execute_item_cmds(conn, [
          cmd.DeleteItemByNameAndAge(name: name, age: age),
        ])
      {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
  }
}

fn not_found_item_name_and_age_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "item" <> " not found: " <> op, -1)
}
