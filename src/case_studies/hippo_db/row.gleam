import api_help
import case_studies/hippo_schema
import dsl/dsl
import gleam/dynamic/decode
import gleam/option

pub fn human_with_magic_row_decoder() -> decode.Decoder(
  #(hippo_schema.Human, dsl.MagicFields),
) {
  use name_raw <- decode.field(0, decode.string)
  use email_raw <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let name = api_help.opt_string_from_db(name_raw)
  let email = api_help.opt_string_from_db(email_raw)
  let human =
    hippo_schema.Human(
      name:,
      email:,
      hippos: [],
      identities: hippo_schema.ByEmail(email: email_raw),
      relationships: hippo_schema.HumanRelationships(hippos: dsl.BacklinkWith(
        [],
        option.None,
      )),
    )
  decode.success(#(
    human,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn gender_scalar_to_db_string(
  o: option.Option(hippo_schema.GenderScalar),
) -> String {
  case o {
    option.None -> ""
    option.Some(hippo_schema.Male) -> "Male"
    option.Some(hippo_schema.Female) -> "Female"
  }
}

pub fn gender_scalar_from_db_string(
  s: String,
) -> option.Option(hippo_schema.GenderScalar) {
  case s {
    "" -> option.None
    "Male" -> option.Some(hippo_schema.Male)
    "Female" -> option.Some(hippo_schema.Female)
    _ -> option.None
  }
}

pub fn hippo_with_magic_row_decoder() -> decode.Decoder(
  #(hippo_schema.Hippo, dsl.MagicFields),
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
  let hippo =
    hippo_schema.Hippo(
      name:,
      gender:,
      date_of_birth:,
      identities: hippo_schema.ByNameAndDateOfBirth(
        name: name_raw,
        date_of_birth: dob_identity,
      ),
      relationships: hippo_schema.HippoRelationships(
        friends: option.None,
        best_friend: option.None,
        owner: option.None,
      ),
    )
  decode.success(#(
    hippo,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
