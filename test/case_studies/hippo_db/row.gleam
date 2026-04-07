pub type HippoRow {
  HippoRow(
    name: option.Option(String),
    gender: option.Option(hippo_schema.GenderScalar),
    date_of_birth: option.Option(Date),
    friends: List(#(hippo_schema.Hippo, hippo_schema.FriendshipAttributes)),
    best_friend: option.Option(
      #(hippo_schema.Hippo, hippo_schema.FriendshipAttributes),
    ),
    owner: option.Option(hippo_schema.Human),
  )
}

pub type HumanRow {
  HumanRow(
    name: option.Option(String),
    email: option.Option(String),
    hippos: List(#(hippo_schema.Hippo, hippo_schema.FriendshipAttributes)),
  )
}

import case_studies/hippo_schema
import gleam/dynamic/decode
import gleam/option
import gleam/time/calendar.{type Date}
import swil/dsl
import swil/runtime/api_help

pub fn human_with_magic_row_decoder() -> decode.Decoder(
  #(HumanRow, dsl.MagicFields),
) {
  use name_raw <- decode.field(0, decode.string)
  use email_raw <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let name = api_help.opt_string_from_db(name_raw)
  let email = api_help.opt_string_from_db(email_raw)
  let human_row = HumanRow(name:, email:, hippos: [])
  decode.success(#(
    human_row,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn gender_scalar_to_db_string(
  o o: option.Option(hippo_schema.GenderScalar),
) -> String {
  case o {
    option.None -> ""
    option.Some(hippo_schema.Male) -> "Male"
    option.Some(hippo_schema.Female) -> "Female"
  }
}

pub fn gender_scalar_from_db_string(
  s s: String,
) -> option.Option(hippo_schema.GenderScalar) {
  case s {
    "" -> option.None
    "Male" -> option.Some(hippo_schema.Male)
    "Female" -> option.Some(hippo_schema.Female)
    _ -> option.None
  }
}

pub fn hippo_with_magic_row_decoder() -> decode.Decoder(
  #(HippoRow, dsl.MagicFields),
) {
  use name_raw <- decode.field(0, decode.string)
  use gender_raw <- decode.field(1, decode.string)
  use dob_raw <- decode.field(2, decode.string)
  use id <- decode.field(3, decode.int)
  use created_at <- decode.field(4, decode.int)
  use updated_at <- decode.field(5, decode.int)
  use deleted_at_raw <- decode.field(6, decode.optional(decode.int))
  let name = api_help.opt_string_from_db(name_raw)
  let gender = gender_scalar_from_db_string(gender_raw)
  let date_of_birth = case dob_raw {
    "" -> option.None
    s -> option.Some(api_help.date_from_db_string(s))
  }
  let assert option.Some(dob_identity) = date_of_birth
  let hippo_row =
    HippoRow(
      name:,
      gender:,
      date_of_birth:,
      friends: [],
      best_friend: option.None,
      owner: option.None,
    )
  decode.success(#(
    hippo_row,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub type QueryOldHipposOwnerEmailsOutput {
  QueryOldHipposOwnerEmailsOutput(age: Int, owner_email: option.Option(String))
}

pub fn query_old_hippos_owner_emails_output_decoder() -> decode.Decoder(
  QueryOldHipposOwnerEmailsOutput,
) {
  use age <- decode.field(0, decode.int)
  use owner_email <- decode.field(1, decode.optional(decode.string))
  decode.success(QueryOldHipposOwnerEmailsOutput(age:, owner_email:))
}

pub type QueryOldHipposOwnerNamesOutput {
  QueryOldHipposOwnerNamesOutput(age: Int, owner_email: option.Option(String))
}

pub fn query_old_hippos_owner_names_output_decoder() -> decode.Decoder(
  QueryOldHipposOwnerNamesOutput,
) {
  use age <- decode.field(0, decode.int)
  use owner_email <- decode.field(1, decode.optional(decode.string))
  decode.success(QueryOldHipposOwnerNamesOutput(age:, owner_email:))
}
