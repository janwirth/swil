import gleam/dynamic/decode
import gleam/result
import gleam/time/calendar
import sqlight
import swil/api_help

const soft_delete_human_by_email_sql = "update \"human\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"email\" = ? and \"deleted_at\" is null returning \"email\";"

const soft_delete_hippo_by_name_and_date_of_birth_sql = "update \"hippo\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null returning \"name\", \"date_of_birth\";"

/// Delete a human by the `ByEmail` identity.
pub fn delete_human_by_email(
  conn: sqlight.Connection,
  email email: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_human_by_email_sql,
      on: conn,
      with: [sqlight.int(now), sqlight.int(now), sqlight.text(email)],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_human_email_error("delete_human_by_email"))
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
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_hippo_by_name_and_date_of_birth_sql,
      on: conn,
      with: [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(name),
        sqlight.text(api_help.date_to_db_string(date_of_birth)),
      ],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] ->
      Error(not_found_hippo_name_and_date_of_birth_error(
        "delete_hippo_by_name_and_date_of_birth",
      ))
  }
}

fn not_found_hippo_name_and_date_of_birth_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "hippo" <> " not found: " <> op,
    -1,
  )
}
