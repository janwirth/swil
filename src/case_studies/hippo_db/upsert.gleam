import case_studies/hippo_db/row
import case_studies/hippo_schema
import gleam/option
import gleam/result
import gleam/time/calendar
import skwil/api_help
import skwil/dsl/dsl
import sqlight

const update_human_by_id_sql = "update \"human\" set \"name\" = ?, \"email\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"name\", \"email\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_human_by_email_sql = "update \"human\" set \"name\" = ?, \"updated_at\" = ? where \"email\" = ? and \"deleted_at\" is null returning \"name\", \"email\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_human_by_email_sql = "insert into \"human\" (\"name\", \"email\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"email\") do update set
  \"name\" = excluded.\"name\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"name\", \"email\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_hippo_by_id_sql = "update \"hippo\" set \"name\" = ?, \"gender\" = ?, \"date_of_birth\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_hippo_by_name_and_date_of_birth_sql = "update \"hippo\" set \"gender\" = ?, \"updated_at\" = ? where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null returning \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_hippo_by_name_and_date_of_birth_sql = "insert into \"hippo\" (\"name\", \"gender\", \"date_of_birth\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"name\", \"date_of_birth\") do update set
  \"gender\" = excluded.\"gender\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

/// Update a human by row id (all scalar columns, including natural-key fields).
pub fn update_human_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  email email: option.Option(String),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_name = api_help.opt_text_for_db(name)
  let db_email = api_help.opt_text_for_db(email)
  use rows <- result.try(sqlight.query(
    update_human_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_name),
      sqlight.text(db_email),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.human_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_human_id_error("update_human_by_id"))
  }
}

fn not_found_human_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "human" <> " not found: " <> op,
    -1,
  )
}

/// Update a human by the `ByEmail` identity.
pub fn update_human_by_email(
  conn: sqlight.Connection,
  email email: String,
  name name: option.Option(String),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_name = api_help.opt_text_for_db(name)
  use rows <- result.try(sqlight.query(
    update_human_by_email_sql,
    on: conn,
    with: [
      sqlight.text(db_name),
      sqlight.int(now),
      sqlight.text(email),
    ],
    expecting: row.human_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_human_email_error("update_human_by_email"))
  }
}

/// Upsert a human by the `ByEmail` identity.
pub fn upsert_human_by_email(
  conn: sqlight.Connection,
  email email: String,
  name name: option.Option(String),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_name = api_help.opt_text_for_db(name)
  use rows <- result.try(sqlight.query(
    upsert_human_by_email_sql,
    on: conn,
    with: [
      sqlight.text(db_name),
      sqlight.text(email),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.human_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
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
  let now = api_help.unix_seconds_now()
  let db_name = api_help.opt_text_for_db(name)
  let db_date_of_birth = case date_of_birth {
    option.Some(d) -> api_help.date_to_db_string(d)
    option.None -> ""
  }
  use rows <- result.try(sqlight.query(
    update_hippo_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_name),
      sqlight.text(row.gender_scalar_to_db_string(gender)),
      sqlight.text(db_date_of_birth),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.hippo_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_hippo_id_error("update_hippo_by_id"))
  }
}

fn not_found_hippo_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "hippo" <> " not found: " <> op,
    -1,
  )
}

/// Update a hippo by the `ByNameAndDateOfBirth` identity.
pub fn update_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
  gender gender: option.Option(hippo_schema.GenderScalar),
) -> Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    update_hippo_by_name_and_date_of_birth_sql,
    on: conn,
    with: [
      sqlight.text(row.gender_scalar_to_db_string(gender)),
      sqlight.int(now),
      sqlight.text(name),
      sqlight.text(api_help.date_to_db_string(date_of_birth)),
    ],
    expecting: row.hippo_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(not_found_hippo_name_and_date_of_birth_error(
        "update_hippo_by_name_and_date_of_birth",
      ))
  }
}

/// Upsert a hippo by the `ByNameAndDateOfBirth` identity.
pub fn upsert_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
  gender gender: option.Option(hippo_schema.GenderScalar),
) -> Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    upsert_hippo_by_name_and_date_of_birth_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.text(row.gender_scalar_to_db_string(gender)),
      sqlight.text(api_help.date_to_db_string(date_of_birth)),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.hippo_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
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
