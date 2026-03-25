import gleam/option
import sqlight
import case_studies/hippo_schema.{type Hippo, type Human}
import dsl
import gleam/time/calendar.{type Date}

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  let _ = conn
  todo as "TODO: generated migration SQL"
}

/// Generated DB module for the hippo case study.
///
/// This module contains SQL-oriented output generated from schema/query specs.
/// Function bodies are intentionally stubbed during skeleton generation.
/// Upsert a human by the `ByEmail` identity.
pub fn upsert_human_by_email(
  conn: sqlight.Connection,
  email: String,
  name: option.Option(String),
) -> Result(Human, sqlight.Error) {
  let _ = conn
  let _ = email
  let _ = name
  todo as "TODO: generated upsert SQL and decoding"
}

/// Delete a human by the `ByEmail` identity.
pub fn delete_human_by_email(
  conn: sqlight.Connection,
  email: String,
) -> Result(Nil, sqlight.Error) {
  let _ = conn
  let _ = email
  todo as "TODO: generated delete SQL"
}

/// Delete a human by id.
pub fn delete_human_by_id(
  conn: sqlight.Connection,
  id: String,
) -> Result(Nil, sqlight.Error) {
  let _ = conn
  let _ = id
  todo as "TODO: generated delete-by-id SQL"
}

pub type QueryOldHipposOwnerEmailsResult {
  QueryOldHipposOwnerEmailsResult(
    age: Int,
    owner: option.Option(QueryOldHipposOwnerEmailsResultOwner),
  )
}

pub type QueryOldHipposOwnerEmailsResultOwner {
  QueryOldHipposOwnerEmailsResultOwner(email: option.Option(String))
}

/// Execute generated query for the "old hippos owner emails" spec.
pub fn query_old_hippos_owner_emails(
  conn: sqlight.Connection,
  age: Int,
) -> Result(List(QueryOldHipposOwnerEmailsResult), sqlight.Error) {
  let _ = conn
  let _ = age
  todo as "TODO: generated select SQL, parameters, and decoder"
}

pub type HipposByGenderResult {
  HipposByGenderResult(
    magic_fields: dsl.MagicFields,
    name: option.Option(String),
    date_of_birth: option.Option(Date),
    owner: option.Option(#(dsl.MagicFields, Human)),
  )
}

/// Execute generated query for the "hippos by gender" spec.
pub fn query_hippos_by_gender(
  conn: sqlight.Connection,
  gender_to_match: hippo_schema.GenderScalar,
) -> Result(List(HipposByGenderResult), sqlight.Error) {
  let _ = conn
  let _ = gender_to_match
  todo as "TODO: generated select SQL, parameters, and decoder"
}

/// Upsert a hippo record.
pub fn upsert_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: option.Option(hippo_schema.GenderScalar),
) -> Result(Hippo, sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}
