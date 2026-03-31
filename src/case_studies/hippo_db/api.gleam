import case_studies/hippo_db/delete
import case_studies/hippo_db/get
import case_studies/hippo_db/migration
import case_studies/hippo_db/query
import case_studies/hippo_db/row
import case_studies/hippo_db/upsert
import case_studies/hippo_schema
import gleam/list
import gleam/option
import gleam/time/calendar
import sqlight
import swil/dsl/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn gender_scalar_to_db_string(
  o o: option.Option(hippo_schema.GenderScalar),
) -> String {
  row.gender_scalar_to_db_string(o)
}

pub fn gender_scalar_from_db_string(
  s s: String,
) -> option.Option(hippo_schema.GenderScalar) {
  row.gender_scalar_from_db_string(s)
}

pub fn query_hippos_by_gender(
  conn: sqlight.Connection,
  gender_to_match gender_to_match: hippo_schema.GenderScalar,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  query.query_hippos_by_gender(conn, gender_to_match: gender_to_match)
}

pub fn query_old_hippos_owner_names(
  conn: sqlight.Connection,
  min_age min_age: Int,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  query.query_old_hippos_owner_names(conn, min_age: min_age)
}

pub fn query_old_hippos_owner_emails(
  conn: sqlight.Connection,
  min_age min_age: Int,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  query.query_old_hippos_owner_emails(conn, min_age: min_age)
}

pub fn last_100_edited_human(
  conn: sqlight.Connection,
) -> Result(List(#(hippo_schema.Human, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_human(conn)
}

pub fn last_100_edited_hippo(
  conn: sqlight.Connection,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_hippo(conn)
}

pub fn get_human_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(hippo_schema.Human, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_human_by_id(conn, id: id)
}

pub fn get_hippo_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(hippo_schema.Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_hippo_by_id(conn, id: id)
}

pub fn update_human_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  email email: option.Option(String),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  upsert.update_human_by_id(conn, id: id, name: name, email: email)
}

pub fn delete_human_by_email(
  conn: sqlight.Connection,
  email email: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_human_by_email(conn, email: email)
}

pub fn update_human_by_email(
  conn: sqlight.Connection,
  email email: String,
  name name: option.Option(String),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  upsert.update_human_by_email(conn, email: email, name: name)
}

pub fn get_human_by_email(
  conn: sqlight.Connection,
  email email: String,
) -> Result(
  option.Option(#(hippo_schema.Human, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_human_by_email(conn, email: email)
}

pub fn by_human_email(
  email email: String,
  name name: option.Option(String),
) -> fn(sqlight.Connection) ->
  Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  fn(conn) { upsert.upsert_human_by_email(conn, email: email, name: name) }
}

pub fn upsert_many_human(
  conn: sqlight.Connection,
  rows rows: List(
    fn(sqlight.Connection) ->
      Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error),
  ),
) -> Result(List(#(hippo_schema.Human, dsl.MagicFields)), sqlight.Error) {
  list.try_map(rows, fn(row) { row(conn) })
}

pub fn upsert_one_human(
  conn: sqlight.Connection,
  row row: fn(sqlight.Connection) ->
    Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error),
) -> Result(#(hippo_schema.Human, dsl.MagicFields), sqlight.Error) {
  row(conn)
}

pub fn update_hippo_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  gender gender: option.Option(hippo_schema.GenderScalar),
  date_of_birth date_of_birth: option.Option(calendar.Date),
) -> Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  upsert.update_hippo_by_id(
    conn,
    id: id,
    name: name,
    gender: gender,
    date_of_birth: date_of_birth,
  )
}

pub fn delete_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
) -> Result(Nil, sqlight.Error) {
  delete.delete_hippo_by_name_and_date_of_birth(
    conn,
    name: name,
    date_of_birth: date_of_birth,
  )
}

pub fn update_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
  gender gender: option.Option(hippo_schema.GenderScalar),
) -> Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  upsert.update_hippo_by_name_and_date_of_birth(
    conn,
    name: name,
    date_of_birth: date_of_birth,
    gender: gender,
  )
}

pub fn get_hippo_by_name_and_date_of_birth(
  conn: sqlight.Connection,
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
) -> Result(
  option.Option(#(hippo_schema.Hippo, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_hippo_by_name_and_date_of_birth(
    conn,
    name: name,
    date_of_birth: date_of_birth,
  )
}

pub fn by_hippo_name_and_date_of_birth(
  name name: String,
  date_of_birth date_of_birth: calendar.Date,
  gender gender: option.Option(hippo_schema.GenderScalar),
) -> fn(sqlight.Connection) ->
  Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  fn(conn) {
    upsert.upsert_hippo_by_name_and_date_of_birth(
      conn,
      name: name,
      date_of_birth: date_of_birth,
      gender: gender,
    )
  }
}

pub fn upsert_many_hippo(
  conn: sqlight.Connection,
  rows rows: List(
    fn(sqlight.Connection) ->
      Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error),
  ),
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  list.try_map(rows, fn(row) { row(conn) })
}

pub fn upsert_one_hippo(
  conn: sqlight.Connection,
  row row: fn(sqlight.Connection) ->
    Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error),
) -> Result(#(hippo_schema.Hippo, dsl.MagicFields), sqlight.Error) {
  row(conn)
}
