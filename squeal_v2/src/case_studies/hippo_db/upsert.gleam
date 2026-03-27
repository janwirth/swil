import api_help
import dsl/dsl as dsl
import case_studies/hippo_db/row
import case_studies/hippo_schema.{type HumanRelationships, type Human, type HippoRelationships, type Hippo, type GenderScalar, Male, HumanRelationships, Human, HippoRelationships, Hippo, Female, ByNameAndDateOfBirth, ByEmail}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/calendar.{type Date}
import gleam/time/timestamp
import sqlight

const upsert_sql = "insert into \"hippo\" (\"name\", \"gender\", \"date_of_birth\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"name\", \"date_of_birth\") do update set
  \"gender\" = excluded.\"gender\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_by_name_and_date_of_birth_sql = "update \"hippo\" set \"gender\" = ?, \"updated_at\" = ? where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null returning \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_human_sql = "insert into human (name, email, created_at, updated_at, deleted_at)
values (?, ?, ?, ?, null)
on conflict(email) do update set
  name = excluded.name,
  updated_at = excluded.updated_at,
  deleted_at = null
returning name, email, id, created_at, updated_at, deleted_at;"

const set_hippo_owner_sql = "update hippo set owner_human_id = ?, updated_at = ?
where name = ? and date_of_birth = ? and deleted_at is null returning id;"

/// Update a hippo by the `ByNameAndDateOfBirth` identity.
pub fn update_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: Option(GenderScalar),
) -> Result(#(Hippo, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    update_by_name_and_date_of_birth_sql,
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
    [] -> Error(not_found_error("update_hippo_by_name_and_date_of_birth"))
  }
}

/// Upsert a hippo by the `ByNameAndDateOfBirth` identity.
pub fn upsert_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: Option(GenderScalar),
) -> Result(#(Hippo, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    upsert_sql,
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

/// Upsert a human by the `ByEmail` identity.
pub fn upsert_human_by_email(
  conn: sqlight.Connection,
  email: String,
  name: Option(String),
) -> Result(#(Human, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let name_raw = case name {
    Some(s) -> s
    None -> ""
  }
  use rows <- result.try(sqlight.query(
    upsert_human_sql,
    on: conn,
    with: [
      sqlight.text(name_raw),
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
        "upsert_human returned no row",
        -1,
      ))
  }
}

pub fn set_hippo_owner_human_id(
  conn: sqlight.Connection,
  hippo_name: String,
  hippo_date_of_birth: Date,
  owner_human_id: Int,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    set_hippo_owner_sql,
    on: conn,
    with: [
      sqlight.int(owner_human_id),
      sqlight.int(now),
      sqlight.text(hippo_name),
      sqlight.text(api_help.date_to_db_string(hippo_date_of_birth)),
    ],
    expecting: {
      use _id <- decode.field(0, decode.int)
      decode.success(Nil)
    },
  ))
  case rows {
    [_, ..] -> Ok(Nil)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "set_hippo_owner_human_id: hippo not found",
        -1,
      ))
  }
}

fn not_found_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "hippo"
    <>
    " not found: "
    <>
    op,
    -1,
  )
}
