import case_studies/hippo_db/migration
import case_studies/hippo_schema.{type GenderScalar, type Hippo, type HippoRelationships, ByNameAndDateOfBirth, Female, Hippo, HippoRelationships, Male}
import dsl/dsl as dsl
import gleam/dynamic/decode
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar.{type Date, Date as CalDate, month_from_int, month_to_int}
import gleam/time/timestamp
import sqlight

// --- SQL (hippo table shape matches `example_migration_hippo` / pragma migrations) ---
//
// insert into hippo (name, gender, date_of_birth, created_at, updated_at, deleted_at)
//   values (?, ?, ?, ?, ?, null)
//   on conflict(name, date_of_birth) do update set
//     gender = excluded.gender,
//     updated_at = excluded.updated_at,
//     deleted_at = null;
//
// select name, gender, date_of_birth, id, created_at, updated_at, deleted_at from hippo
//   where name = ? and date_of_birth = ? and deleted_at is null;
//
// update hippo set gender = ?, updated_at = ?
//   where name = ? and date_of_birth = ? and deleted_at is null
//   returning name, gender, date_of_birth, id, created_at, updated_at, deleted_at;
//
// update hippo set deleted_at = ?, updated_at = ?
//   where name = ? and date_of_birth = ? and deleted_at is null
//   returning name, date_of_birth;
//
// select name, gender, date_of_birth, id, created_at, updated_at, deleted_at from hippo
//   where deleted_at is null
//   order by updated_at desc
//   limit 100;

const upsert_sql = "insert into hippo (name, gender, date_of_birth, created_at, updated_at, deleted_at)
values (?, ?, ?, ?, ?, null)
on conflict(name, date_of_birth) do update set
  gender = excluded.gender,
  updated_at = excluded.updated_at,
  deleted_at = null
returning name, gender, date_of_birth, id, created_at, updated_at, deleted_at;"

const select_by_name_and_date_of_birth_sql = "select name, gender, date_of_birth, id, created_at, updated_at, deleted_at from hippo where name = ? and date_of_birth = ? and deleted_at is null;"

const update_by_name_and_date_of_birth_sql = "update hippo set gender = ?, updated_at = ? where name = ? and date_of_birth = ? and deleted_at is null returning name, gender, date_of_birth, id, created_at, updated_at, deleted_at;"

const soft_delete_by_name_and_date_of_birth_sql = "update hippo set deleted_at = ?, updated_at = ? where name = ? and date_of_birth = ? and deleted_at is null returning name, date_of_birth;"

const last_100_sql = "select name, gender, date_of_birth, id, created_at, updated_at, deleted_at from hippo where deleted_at is null order by updated_at desc limit 100;"

fn unix_seconds_now() -> Int {
  let #(s, _) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds
  s
}

fn pad2(n: Int) -> String {
  let s = int.to_string(n)
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}

fn date_to_db_string(d: Date) -> String {
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
    _ -> panic as "hippo_db/api: expected YYYY-MM-DD date string"
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

fn opt_string_from_db(s: String) -> Option(String) {
  case s {
    "" -> None
    _ -> Some(s)
  }
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

fn hippo_with_magic_row_decoder() -> decode.Decoder(#(Hippo, dsl.MagicFields)) {
  use name_raw <- decode.field(0, decode.string)
  use gender_raw <- decode.field(1, decode.string)
  use dob_raw <- decode.field(2, decode.string)
  use id <- decode.field(3, decode.int)
  use created_at <- decode.field(4, decode.int)
  use updated_at <- decode.field(5, decode.int)
  use deleted_at_raw <- decode.field(6, decode.optional(decode.int))
  let name = opt_string_from_db(name_raw)
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

fn not_found_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "hippo not found: " <> op, -1)
}

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

/// Upsert a hippo by the `ByNameAndDateOfBirth` identity.
pub fn upsert_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: Option(GenderScalar),
) -> Result(#(Hippo, dsl.MagicFields), sqlight.Error) {
  let now = unix_seconds_now()
  use rows <- result.try(sqlight.query(
    upsert_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.text(gender_scalar_to_db_string(gender)),
      sqlight.text(date_to_db_string(date_of_birth)),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: hippo_with_magic_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(row)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

/// Get a hippo by the `ByNameAndDateOfBirth` identity.
pub fn get_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
) -> Result(Option(#(Hippo, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_by_name_and_date_of_birth_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.text(date_to_db_string(date_of_birth)),
    ],
    expecting: hippo_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [row, ..] -> Ok(Some(row))
  }
}

/// Update a hippo by the `ByNameAndDateOfBirth` identity.
pub fn update_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: Option(GenderScalar),
) -> Result(#(Hippo, dsl.MagicFields), sqlight.Error) {
  let now = unix_seconds_now()
  use rows <- result.try(sqlight.query(
    update_by_name_and_date_of_birth_sql,
    on: conn,
    with: [
      sqlight.text(gender_scalar_to_db_string(gender)),
      sqlight.int(now),
      sqlight.text(name),
      sqlight.text(date_to_db_string(date_of_birth)),
    ],
    expecting: hippo_with_magic_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(row)
    [] -> Error(not_found_error("update_hippo_by_name_and_date_of_birth"))
  }
}

/// Delete a hippo by the `ByNameAndDateOfBirth` identity.
pub fn delete_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
) -> Result(Nil, sqlight.Error) {
  let now = unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_by_name_and_date_of_birth_sql,
      on: conn,
      with: [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(name),
        sqlight.text(date_to_db_string(date_of_birth)),
      ],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_error("delete_hippo_by_name_and_date_of_birth"))
  }
}

/// List up to 100 recently edited hippo rows.
pub fn last_100_edited_hippo(
  conn: sqlight.Connection,
) -> Result(List(#(Hippo, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_sql,
    on: conn,
    with: [],
    expecting: hippo_with_magic_row_decoder(),
  )
}
