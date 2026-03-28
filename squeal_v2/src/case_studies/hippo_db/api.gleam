import case_studies/hippo_db/delete
import dsl/dsl as dsl
import case_studies/hippo_db/get
import case_studies/hippo_db/migration
import case_studies/hippo_db/query
import case_studies/hippo_db/row
import case_studies/hippo_db/upsert
import case_studies/hippo_schema.{type Human, type Hippo, type GenderScalar}
import gleam/option.{type Option}
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

pub fn query_hippos_by_gender(
  conn: sqlight.Connection,
  gender_to_match: GenderScalar,
) -> Result(List(#(Hippo, dsl.MagicFields)), sqlight.Error) {
  query.query_hippos_by_gender(conn, gender_to_match)
}

pub fn query_old_hippos_owner_names(conn: sqlight.Connection, min_age: Int) -> Result(
  List(#(Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  query.query_old_hippos_owner_names(conn, min_age)
}

pub fn query_old_hippos_owner_emails(conn: sqlight.Connection, min_age: Int) -> Result(
  List(#(Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  query.query_old_hippos_owner_emails(conn, min_age)
}

pub fn last_100_edited_human(conn: sqlight.Connection) -> Result(
  List(#(Human, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_human(conn)
}

pub fn last_100_edited_hippo(conn: sqlight.Connection) -> Result(
  List(#(Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_hippo(conn)
}

pub fn get_human_by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(Human, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_human_by_id(conn, id)
}

pub fn get_hippo_by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_hippo_by_id(conn, id)
}

pub fn delete_human_by_email(conn: sqlight.Connection, email: String) -> Result(
  Nil,
  sqlight.Error,
) {
  delete.delete_human_by_email(conn, email)
}

pub fn update_human_by_email(
  conn: sqlight.Connection,
  email: String,
  name: Option(String),
) -> Result(#(Human, dsl.MagicFields), sqlight.Error) {
  upsert.update_human_by_email(conn, email, name)
}

pub fn get_human_by_email(conn: sqlight.Connection, email: String) -> Result(
  Option(#(Human, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_human_by_email(conn, email)
}

pub fn upsert_human_by_email(
  conn: sqlight.Connection,
  email: String,
  name: Option(String),
) -> Result(#(Human, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_human_by_email(conn, email, name)
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
  get.get_hippo_by_name_and_date_of_birth(conn, name, date_of_birth)
}

pub fn upsert_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name: String,
  date_of_birth: Date,
  gender: Option(GenderScalar),
) -> Result(#(Hippo, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_hippo_by_name_and_date_of_birth(conn, name, date_of_birth, gender)
}
