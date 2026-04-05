import case_studies/hippo_db/cmd
import case_studies/hippo_db/get
import case_studies/hippo_schema
import gleam/list
import gleam/option
import gleam/result
import gleam/time/calendar
import sqlight
import swil/dsl/dsl

/// Update a human by row id (all scalar columns, including natural-key fields).
pub fn update_human_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  email email: option.Option(String),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_human_by_id(conn, id))
  case existing {
    option.None -> Error(not_found_human_id_error("update_human_by_id"))
    option.Some(_) -> {
      case
        cmd.execute_human_cmds(conn, [
          cmd.UpdateHumanById(id: id, name: name, email: email),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_human_by_id(conn, id))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None -> Error(not_found_human_id_error("update_human_by_id"))
          }
        }
      }
    }
  }
}

fn not_found_human_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "human" <> " not found: " <> op,
    -1,
  )
}

/// Upsert many human rows by the `ByEmail` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_human_by_email`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_human_by_email(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, option.Option(String)) ->
      Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error),
) -> Result(List(#(hippo_schema.Human, dsl.MagicFields)), sqlight.Error) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(email: String, name: option.Option(String)) {
      upsert_human_by_email(conn, email: email, name: name)
    }
    each(item, upsert_row)
  })
}

/// Update a human by the `ByEmail` identity.
pub fn update_human_by_email(
  conn: sqlight.Connection,
  email email: String,
  name name: option.Option(String),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_human_by_email(conn, email: email))
  case existing {
    option.None -> Error(not_found_human_email_error("update_human_by_email"))
    option.Some(_) -> {
      case
        cmd.execute_human_cmds(conn, [
          cmd.UpdateHumanByEmail(email: email, name: name),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_human_by_email(conn, email: email))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_human_email_error("update_human_by_email"))
          }
        }
      }
    }
  }
}

/// Upsert a human by the `ByEmail` identity.
pub fn upsert_human_by_email(
  conn: sqlight.Connection,
  email email: String,
  name name: option.Option(String),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  case
    cmd.execute_human_cmds(conn, [
      cmd.UpsertHumanByEmail(email: email, name: name),
    ])
  {
    Error(#(_, e)) -> Error(e)
    Ok(Nil) -> {
      use row_opt <- result.try(get.get_human_by_email(conn, email: email))
      case row_opt {
        option.Some(r) -> Ok(r)
        option.None ->
          Error(sqlight.SqlightError(
            sqlight.GenericError,
            "upsert returned no row",
            -1,
          ))
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

/// Update a hippo by row id (all scalar columns, including natural-key fields).
pub fn update_hippo_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  gender gender: option.Option(hippo_schema.GenderScalar),
  date_of_birth date_of_birth: option.Option(calendar.Date),
) -> Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_hippo_by_id(conn, id))
  case existing {
    option.None -> Error(not_found_hippo_id_error("update_hippo_by_id"))
    option.Some(_) -> {
      case
        cmd.execute_hippo_cmds(conn, [
          cmd.UpdateHippoById(
            id: id,
            name: name,
            gender: gender,
            date_of_birth: date_of_birth,
          ),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_hippo_by_id(conn, id))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None -> Error(not_found_hippo_id_error("update_hippo_by_id"))
          }
        }
      }
    }
  }
}

fn not_found_hippo_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "hippo" <> " not found: " <> op,
    -1,
  )
}

/// Upsert many hippo rows by the `ByNameAndDateOfBirth` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_hippo_by_name_and_date_of_birth`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, calendar.Date, option.Option(hippo_schema.GenderScalar)) ->
      Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error),
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(
      name: String,
      date_of_birth: calendar.Date,
      gender: option.Option(hippo_schema.GenderScalar),
    ) {
      upsert_hippo_by_name_and_date_of_birth(
        conn,
        name: name,
        date_of_birth: date_of_birth,
        gender: gender,
      )
    }
    each(item, upsert_row)
  })
}

/// Update a hippo by the `ByNameAndDateOfBirth` identity.
pub fn update_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
  gender gender: option.Option(hippo_schema.GenderScalar),
) -> Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_hippo_by_name_and_date_of_birth(
    conn,
    name: name,
    date_of_birth: date_of_birth,
  ))
  case existing {
    option.None ->
      Error(not_found_hippo_name_and_date_of_birth_error(
        "update_hippo_by_name_and_date_of_birth",
      ))
    option.Some(_) -> {
      case
        cmd.execute_hippo_cmds(conn, [
          cmd.UpdateHippoByNameAndDateOfBirth(
            name: name,
            date_of_birth: date_of_birth,
            gender: gender,
          ),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_hippo_by_name_and_date_of_birth(
            conn,
            name: name,
            date_of_birth: date_of_birth,
          ))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_hippo_name_and_date_of_birth_error(
                "update_hippo_by_name_and_date_of_birth",
              ))
          }
        }
      }
    }
  }
}

/// Upsert a hippo by the `ByNameAndDateOfBirth` identity.
pub fn upsert_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
  gender gender: option.Option(hippo_schema.GenderScalar),
) -> Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  case
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: name,
        date_of_birth: date_of_birth,
        gender: gender,
      ),
    ])
  {
    Error(#(_, e)) -> Error(e)
    Ok(Nil) -> {
      use row_opt <- result.try(get.get_hippo_by_name_and_date_of_birth(
        conn,
        name: name,
        date_of_birth: date_of_birth,
      ))
      case row_opt {
        option.Some(r) -> Ok(r)
        option.None ->
          Error(sqlight.SqlightError(
            sqlight.GenericError,
            "upsert returned no row",
            -1,
          ))
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
