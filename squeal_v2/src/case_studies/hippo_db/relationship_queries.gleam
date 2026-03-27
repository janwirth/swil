import api_help
import case_studies/hippo_db/api as hippo_api
import case_studies/hippo_schema.{
  type GenderScalar, type Human, ByEmail, Human, HumanRelationships,
}
import dsl/dsl as dsl
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/calendar.{type Date}
import sqlight

/// One row for [`hippo_schema.old_hippos_owner_emails`](src/case_studies/hippo_schema.gleam).
pub type OldHipposOwnerEmailRow {
  OldHipposOwnerEmailRow(age: Int, owner_email: Option(String))
}

/// One row for [`hippo_schema.hippos_by_gender`](src/case_studies/hippo_schema.gleam).
pub type HipposByGenderRow {
  HipposByGenderRow(
    magic_fields: dsl.MagicFields,
    name: Option(String),
    date_of_birth: Option(Date),
    owner: Option(#(Human, dsl.MagicFields)),
  )
}

const old_hippos_owner_emails_sql = "select
  cast((julianday('now') - julianday(h.date_of_birth)) / 365.25 as int),
  case when hu.email is null then '' else hu.email end
from hippo \"h\"
left join human \"hu\" on h.owner_human_id = hu.id and hu.deleted_at is null
where h.deleted_at is null
  and cast((julianday('now') - julianday(h.date_of_birth)) / 365.25 as int) > ?
order by 1 desc;"

const hippos_by_gender_sql = "select
  h.name, h.gender, h.date_of_birth, h.id, h.created_at, h.updated_at, h.deleted_at, h.owner_human_id,
  hu.name, hu.email, hu.id, hu.created_at, hu.updated_at, hu.deleted_at
from hippo \"h\"
left join human \"hu\" on h.owner_human_id = hu.id and hu.deleted_at is null
where h.deleted_at is null and h.gender = ?
order by h.name desc;"

const upsert_human_sql = "insert into human (name, email, created_at, updated_at, deleted_at)
values (?, ?, ?, ?, null)
on conflict(email) do update set
  name = excluded.name,
  updated_at = excluded.updated_at,
  deleted_at = null
returning name, email, id, created_at, updated_at, deleted_at;"

const set_hippo_owner_sql = "update hippo set owner_human_id = ?, updated_at = ?
where name = ? and date_of_birth = ? and deleted_at is null returning id;"

fn human_with_magic_row_decoder() -> decode.Decoder(#(Human, dsl.MagicFields)) {
  use name_raw <- decode.field(0, decode.string)
  use email_raw <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let human =
    Human(
      name: api_help.opt_string_from_db(name_raw),
      email: api_help.opt_string_from_db(email_raw),
      hippos: [],
      identities: ByEmail(email: email_raw),
      relationships: HumanRelationships(hippos: dsl.BacklinkWith([], None)),
    )
  decode.success(#(
    human,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

fn hippos_by_gender_row_decoder() -> decode.Decoder(HipposByGenderRow) {
  use h_name <- decode.field(0, decode.string)
  use h_gender <- decode.field(1, decode.string)
  use h_dob <- decode.field(2, decode.string)
  use h_id <- decode.field(3, decode.int)
  use h_created <- decode.field(4, decode.int)
  use h_updated <- decode.field(5, decode.int)
  use h_deleted <- decode.field(6, decode.optional(decode.int))
  use _owner_id <- decode.field(7, decode.optional(decode.int))
  use hu_name_raw <- decode.field(8, decode.optional(decode.string))
  use hu_email_raw <- decode.field(9, decode.optional(decode.string))
  use hu_id <- decode.field(10, decode.optional(decode.int))
  use hu_created <- decode.field(11, decode.optional(decode.int))
  use hu_updated <- decode.field(12, decode.optional(decode.int))
  use hu_deleted_raw <- decode.field(13, decode.optional(decode.int))
  let hippo_name = api_help.opt_string_from_db(h_name)
  let _hippo_gender = hippo_api.gender_scalar_from_db_string(h_gender)
  let hippo_dob = case h_dob {
    "" -> None
    s -> Some(api_help.date_from_db_string(s))
  }
  let assert Some(_dob_identity) = hippo_dob
  let owner = case hu_id, hu_name_raw, hu_email_raw, hu_created, hu_updated {
    Some(hid), Some(nraw), Some(eraw), Some(hc), Some(hu) -> {
      let hu_del = hu_deleted_raw
      let human =
        Human(
          name: api_help.opt_string_from_db(nraw),
          email: api_help.opt_string_from_db(eraw),
          hippos: [],
          identities: ByEmail(email: eraw),
          relationships: HumanRelationships(hippos: dsl.BacklinkWith([], None)),
        )
      Some(#(human, api_help.magic_from_db_row(hid, hc, hu, hu_del)))
    }
    _, _, _, _, _ -> None
  }
  let hippo_magic = api_help.magic_from_db_row(h_id, h_created, h_updated, h_deleted)
  decode.success(HipposByGenderRow(
    magic_fields: hippo_magic,
    name: hippo_name,
    date_of_birth: hippo_dob,
    owner:,
  ))
}

/// Upsert a human by unique `email` (see `HumanIdentities.ByEmail`).
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
    expecting: human_with_magic_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(row)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert_human returned no row",
        -1,
      ))
  }
}

/// Point `hippo.owner_human_id` at an existing human row ( BelongsTo owner edge ).
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

/// [`hippo_schema.old_hippos_owner_emails`](src/case_studies/hippo_schema.gleam) — age in whole years via SQLite `julianday`, ordered oldest-first by age (descending age value).
pub fn query_old_hippos_owner_emails(
  conn: sqlight.Connection,
  min_age: Int,
) -> Result(List(OldHipposOwnerEmailRow), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    old_hippos_owner_emails_sql,
    on: conn,
    with: [sqlight.int(min_age)],
    expecting: {
      use age <- decode.field(0, decode.int)
      use email_raw <- decode.field(1, decode.string)
      decode.success(OldHipposOwnerEmailRow(
        age:,
        owner_email: api_help.opt_string_from_db(email_raw),
      ))
    },
  ))
  Ok(rows)
}

/// [`hippo_schema.hippos_by_gender`](src/case_studies/hippo_schema.gleam) — filters non-null stored gender, includes optional joined owner row.
pub fn query_hippos_by_gender(
  conn: sqlight.Connection,
  gender_to_match: GenderScalar,
) -> Result(List(HipposByGenderRow), sqlight.Error) {
  sqlight.query(
    hippos_by_gender_sql,
    on: conn,
    with: [
      sqlight.text(hippo_api.gender_scalar_to_db_string(Some(gender_to_match))),
    ],
    expecting: hippos_by_gender_row_decoder(),
  )
}
