import case_studies/hippo_db/cmd
import case_studies/hippo_db/get
import gleam/option
import gleam/result
import gleam/time/calendar
import sqlight

/// Delete a human by the `ByEmail` identity.
pub fn delete_human_by_email(
  conn: sqlight.Connection,
  email email: String,
) -> Result(Nil, sqlight.Error) {
  use existing <- result.try(get.get_human_by_email(conn, email: email))
  case existing {
    option.None -> Error(not_found_human_email_error("delete_human_by_email"))
    option.Some(_) -> {
      case
        cmd.execute_human_cmds(conn, [cmd.DeleteHumanByEmail(email: email)])
      {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
  }
}

fn not_found_human_email_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "human" <> " not found: " <> op,
    -1,
  )
}

/// Delete a hippo by the `ByNameAndDateOfBirth` identity.
pub fn delete_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
) -> Result(Nil, sqlight.Error) {
  use existing <- result.try(get.get_hippo_by_name_and_date_of_birth(
    conn,
    name: name,
    date_of_birth: date_of_birth,
  ))
  case existing {
    option.None ->
      Error(not_found_hippo_name_and_date_of_birth_error(
        "delete_hippo_by_name_and_date_of_birth",
      ))
    option.Some(_) -> {
      case
        cmd.execute_hippo_cmds(conn, [
          cmd.DeleteHippoByNameAndDateOfBirth(
            name: name,
            date_of_birth: date_of_birth,
          ),
        ])
      {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
  }
}

fn not_found_hippo_name_and_date_of_birth_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "hippo" <> " not found: " <> op,
    -1,
  )
}
