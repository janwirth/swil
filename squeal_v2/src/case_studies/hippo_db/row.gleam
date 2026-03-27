import api_help
import dsl/dsl as dsl
import case_studies/hippo_schema.{type GenderScalar, type Hippo, type HippoRelationships, ByNameAndDateOfBirth, Female, Hippo, HippoRelationships, Male}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/time/calendar.{type Date}

pub fn gender_scalar_to_db_string(o: Option(GenderScalar)) -> String {
  case o {
    None -> ""
    Some(Male) -> "Male"
    Some(Female) -> "Female"
  }
}

pub fn gender_scalar_from_db_string(s: String) -> Option(GenderScalar) {
  case s {
    "" -> None
    "Male" -> Some(Male)
    "Female" -> Some(Female)
    _ -> None
  }
}

pub fn hippo_with_magic_row_decoder() -> decode.Decoder(#(Hippo, dsl.MagicFields)) {
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
    "" -> None
    s -> Some(api_help.date_from_db_string(s))
  }
  let assert Some(dob_identity) = date_of_birth
  let hippo =
    Hippo(
      name:,
      gender:,
      date_of_birth:,
      identities: ByNameAndDateOfBirth(name: name_raw, date_of_birth: dob_identity),
      relationships: HippoRelationships(
        friends: None,
        best_friend: None,
        owner: None,
      ),
    )
  decode.success(#(
    hippo,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

