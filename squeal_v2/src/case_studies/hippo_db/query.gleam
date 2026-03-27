import case_studies/hippo_db/row
import dsl/dsl as dsl
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import case_studies/hippo_schema.{type HumanRelationships, type Human, type HippoRelationships, type Hippo, type GenderScalar, Male, HumanRelationships, Human, HippoRelationships, Hippo, Female, ByNameAndDateOfBirth, ByEmail}
import api_help
import sqlight
import gleam/time/calendar.{type Date}

pub type OldHipposOwnerEmailRow {
  OldHipposOwnerEmailRow(age: Int, owner_email: Option(String))
}

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

const hippos_by_gender_basic_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"deleted_at\" is null and \"gender\" = ? order by \"name\" desc;"

const last_100_human_sql = "select \"name\", \"email\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"human\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

const last_100_hippo_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// `gender == gender_to_match`, ordered descending by `name` (from `query_hippos_by_gender` query spec).
pub fn query_hippos_by_gender(
  conn: sqlight.Connection,
  gender_to_match: GenderScalar,
) -> Result(List(#(Hippo, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    hippos_by_gender_basic_sql,
    on: conn,
    with: [sqlight.text(row.gender_scalar_to_db_string(Some(gender_to_match)))],
    expecting: row.hippo_with_magic_row_decoder(),
  )
}

/// Extended relationship-aware version of `query_hippos_by_gender` including optional owner row.
pub fn query_hippos_by_gender_with_owner(
  conn: sqlight.Connection,
  gender_to_match: GenderScalar,
) -> Result(List(HipposByGenderRow), sqlight.Error) {
  sqlight.query(
    hippos_by_gender_sql,
    on: conn,
    with: [sqlight.text(row.gender_scalar_to_db_string(Some(gender_to_match)))],
    expecting: hippos_by_gender_row_decoder(),
  )
}

/// Age-in-years filtered rows with optional owner email.
pub fn query_old_hippos_owner_emails(
  conn: sqlight.Connection,
  min_age: Int,
) -> Result(List(OldHipposOwnerEmailRow), sqlight.Error) {
  sqlight.query(
    old_hippos_owner_emails_sql,
    on: conn,
    with: [sqlight.int(min_age)],
    expecting: {
      use age <- decode.field(0, decode.int)
      use email_raw <- decode.field(1, decode.string)
      decode.success(OldHipposOwnerEmailRow(
        age: age,
        owner_email: api_help.opt_string_from_db(email_raw),
      ))
    },
  )
}

/// List up to 100 recently edited human rows.
pub fn last_100_edited_human(
  conn: sqlight.Connection,
) -> Result(List(#(Human, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_human_sql,
    on: conn,
    with: [],
    expecting: row.human_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited hippo rows.
pub fn last_100_edited_hippo(
  conn: sqlight.Connection,
) -> Result(List(#(Hippo, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_hippo_sql,
    on: conn,
    with: [],
    expecting: row.hippo_with_magic_row_decoder(),
  )
}

fn hippos_by_gender_row_decoder() -> decode.Decoder(HipposByGenderRow) {
  use h_name <- decode.field(0, decode.string)
  use _h_gender <- decode.field(1, decode.string)
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
  let hippo_dob = case h_dob {
    "" -> None
    s -> Some(api_help.date_from_db_string(s))
  }
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
  decode.success(HipposByGenderRow(
    magic_fields: api_help.magic_from_db_row(h_id, h_created, h_updated, h_deleted),
    name: hippo_name,
    date_of_birth: hippo_dob,
    owner: owner,
  ))
}
