import api_help
import case_studies/hippo_schema.{type GenderScalar, type Hippo, type HippoRelationships, ByNameAndDateOfBirth, Female, Hippo, HippoRelationships, Male}
import dsl/dsl as dsl
import gleam/dynamic/decode
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/calendar.{type Date, Date as CalDate, month_from_int, month_to_int}
import gleam/time/timestamp

fn pad2(n: Int) -> String {
  let s = int.to_string(n)
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}

pub fn date_to_db_string(d: Date) -> String {
  let CalDate(year:, month:, day:) = d
  int.to_string(year)
  <> "-"
  <> pad2(month_to_int(month))
  <> "-"
  <> pad2(day)
}

fn date_from_db_string(s: String) -> Date {
  case string.split(s, "-") {
    [ys, ms, ds] -> {
      let assert Ok(y) = int.parse(ys)
      let assert Ok(mi) = int.parse(ms)
      let assert Ok(d) = int.parse(ds)
      let assert Ok(month) = month_from_int(mi)
      CalDate(y, month, d)
    }
    _ -> panic as "hippo_db/row: expected YYYY-MM-DD date string"
  }
}

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
    s -> Some(date_from_db_string(s))
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
    magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

fn magic_from_db_row(
  id: Int,
  created_s: Int,
  updated_s: Int,
  deleted_raw: Option(Int),
) -> dsl.MagicFields {
  dsl.MagicFields(
    id:,
    created_at: timestamp.from_unix_seconds(created_s),
    updated_at: timestamp.from_unix_seconds(updated_s),
    deleted_at: case deleted_raw {
      Some(s) -> Some(timestamp.from_unix_seconds(s))
      None -> None
    },
  )
}
