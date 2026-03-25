import case_studies/hippo_schema.{type Hippo, type Human}
import dsl
import gleam/option
import gleam/time/calendar.{type Date}
import sqlight

/// Generated from `case_studies/hippo_schema`.
///
/// Table of contents:
/// - `migrate/1`
/// - Entity ops: Hippo, Human
/// - Query specs: `query_old_hippos_owner_emails`, `query_hippos_by_gender`
pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated migration SQL"
}

/// Upsert a hippo by the `ByNameAndDateOfBirth` identity.
pub fn upsert_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: option.Option(hippo_schema.GenderScalar),
) -> Result(Hippo, sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// Get a hippo by the `ByNameAndDateOfBirth` identity.
pub fn get_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
) -> Result(option.Option(Hippo), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Update a hippo by the `ByNameAndDateOfBirth` identity.
pub fn update_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: option.Option(hippo_schema.GenderScalar),
) -> Result(Hippo, sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Delete a hippo by the `ByNameAndDateOfBirth` identity.
pub fn delete_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// List up to 100 recently edited hippo rows.
pub fn last_100_edited_hippo(
  conn: sqlight.Connection,
) -> Result(List(Hippo), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Upsert a human by the `ByEmail` identity.
pub fn upsert_human_by_email(
  conn: sqlight.Connection,
  email: String,
  name: option.Option(String),
) -> Result(#(Human, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// Get a human by the `ByEmail` identity.
pub fn get_human_by_email(
  conn: sqlight.Connection,
  email: String,
) -> Result(option.Option(#(Human, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Update a human by the `ByEmail` identity.
pub fn update_human_by_email(
  conn: sqlight.Connection,
  email: String,
  name: option.Option(String),
) -> Result(Human, sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Delete a human by the `ByEmail` identity.
pub fn delete_human_by_email(
  conn: sqlight.Connection,
  email: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// List up to 100 recently edited human rows.
pub fn last_100_edited_human(
  conn: sqlight.Connection,
) -> Result(List(#(Human, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

pub type QueryOldHipposOwnerEmailsRow {
  QueryOldHipposOwnerEmailsRow
}

/// Execute generated query for the `old_hippos_owner_emails` spec.
pub fn query_old_hippos_owner_emails(
  conn: sqlight.Connection,
  min_age: Int,
) -> Result(List(QueryOldHipposOwnerEmailsRow), sqlight.Error) {
  todo as "TODO: generated select SQL, parameters, and decoder"
}

pub type HipposByGenderResult {
  HipposByGenderResult(
    magic_fields: dsl.MagicFields,
    name: option.Option(String),
    date_of_birth: option.Option(Date),
    owner: option.Option(#(Human, dsl.MagicFields)),
  )
}

/// Execute generated query for the `hippos_by_gender` spec.
pub fn query_hippos_by_gender(
  conn: sqlight.Connection,
  gender_to_match: hippo_schema.GenderScalar,
) -> Result(List(HipposByGenderResult), sqlight.Error) {
  todo as "TODO: generated select SQL, parameters, and decoder"
}
