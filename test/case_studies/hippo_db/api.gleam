import case_studies/hippo_db/cmd
import case_studies/hippo_db/get
import case_studies/hippo_db/migration
import case_studies/hippo_db/query
import case_studies/hippo_db/row
import case_studies/hippo_schema
import gleam/option
import gleam/time/calendar
import sqlight
import swil/dsl

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
) -> Result(List(#(Int, option.Option(String))), sqlight.Error) {
  query.query_old_hippos_owner_names(conn, min_age: min_age)
}

pub fn query_old_hippos_owner_emails(
  conn: sqlight.Connection,
  min_age min_age: Int,
) -> Result(List(#(Int, option.Option(String))), sqlight.Error) {
  query.query_old_hippos_owner_emails(conn, min_age: min_age)
}

pub fn page_edited_human(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(hippo_schema.Human, dsl.MagicFields)), sqlight.Error) {
  query.page_edited_human(conn, limit: limit, offset: offset)
}

pub fn page_edited_hippo(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  query.page_edited_hippo(conn, limit: limit, offset: offset)
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

pub fn get_human_by_email(
  conn: sqlight.Connection,
  email email: String,
) -> Result(
  option.Option(#(hippo_schema.Human, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_human_by_email(conn, email: email)
}

pub fn execute_human_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.HumanCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_human_cmds(conn, commands)
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

pub fn execute_hippo_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.HippoCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_hippo_cmds(conn, commands)
}
