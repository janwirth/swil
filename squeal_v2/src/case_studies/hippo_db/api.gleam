import case_studies/hippo_db/delete
import dsl/dsl as dsl
import case_studies/hippo_db/migration
import case_studies/hippo_db/query
import case_studies/hippo_db/row
import case_studies/hippo_db/upsert
import case_studies/hippo_schema.{type GenderScalar, type Hippo, type HippoRelationships, ByNameAndDateOfBirth, Female, Hippo, HippoRelationships, Male}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/calendar.{type Date, Date as CalDate, month_from_int, month_to_int}
import sqlight

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn gender_scalar_to_db_string(o: Option(GenderScalar)) -> String {
  row.gender_scalar_to_db_string(o)
}

pub fn gender_scalar_from_db_string(s: String) -> Option(GenderScalar) {
  row.gender_scalar_from_db_string(s)
}

pub fn last_100_edited_hippo(conn: sqlight.Connection) -> Result(
  List(#(Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_hippo(conn)
}

pub fn delete_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
) -> Result(Nil, sqlight.Error) {
  delete.delete_hippo_by_name_and_date_of_birth(conn, name, date_of_birth)
}

pub fn update_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: Option(GenderScalar),
) -> Result(#(Hippo, dsl.MagicFields), sqlight.Error) {
  upsert.update_hippo_by_name_and_date_of_birth(conn, name, date_of_birth, gender)
}

pub fn get_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
) -> Result(Option(#(Hippo, dsl.MagicFields)), sqlight.Error) {
  upsert.get_hippo_by_name_and_date_of_birth(conn, name, date_of_birth)
}

pub fn upsert_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: Option(GenderScalar),
) -> Result(#(Hippo, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_hippo_by_name_and_date_of_birth(conn, name, date_of_birth, gender)
}
