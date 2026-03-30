import case_studies/hippo_db/row
import case_studies/hippo_schema
import gleam/option
import gleam/result
import gleam/time/calendar
import swil/api_help
import swil/dsl/dsl
import sqlight

const select_human_by_id_sql = "select \"name\", \"email\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"human\" where \"id\" = ? and \"deleted_at\" is null;"

const select_human_by_email_sql = "select \"name\", \"email\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"human\" where \"email\" = ? and \"deleted_at\" is null;"

const select_hippo_by_id_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"id\" = ? and \"deleted_at\" is null;"

const select_hippo_by_name_and_date_of_birth_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null;"

/// Get a human by row id.
pub fn get_human_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(hippo_schema.Human, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_human_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.human_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a human by the `ByEmail` identity.
pub fn get_human_by_email(
  conn: sqlight.Connection,
  email email: String,
) -> Result(
  option.Option(#(hippo_schema.Human, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_human_by_email_sql,
    on: conn,
    with: [sqlight.text(email)],
    expecting: row.human_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a hippo by row id.
pub fn get_hippo_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(hippo_schema.Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_hippo_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.hippo_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a hippo by the `ByNameAndDateOfBirth` identity.
pub fn get_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
) -> Result(
  option.Option(#(hippo_schema.Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_hippo_by_name_and_date_of_birth_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.text(api_help.date_to_db_string(date_of_birth)),
    ],
    expecting: row.hippo_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}
