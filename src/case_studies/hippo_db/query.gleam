import case_studies/hippo_db/row
import case_studies/hippo_schema
import gleam/option
import skwil/dsl/dsl
import sqlight

const hippos_by_gender_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"deleted_at\" is null and \"gender\" = ? order by \"name\" desc;"

const old_hippos_owner_names_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"deleted_at\" is null and cast((julianday('now') - julianday(\"date_of_birth\")) / 365.25 as int) > ? order by cast((julianday('now') - julianday(\"date_of_birth\")) / 365.25 as int) desc;"

const old_hippos_owner_emails_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"deleted_at\" is null and cast((julianday('now') - julianday(\"date_of_birth\")) / 365.25 as int) > ? order by cast((julianday('now') - julianday(\"date_of_birth\")) / 365.25 as int) desc;"

const last_100_human_sql = "select \"name\", \"email\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"human\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

const last_100_hippo_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

pub fn query_hippos_by_gender(
  conn: sqlight.Connection,
  gender_to_match gender_to_match: hippo_schema.GenderScalar,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    hippos_by_gender_sql,
    on: conn,
    with: [
      sqlight.text(row.gender_scalar_to_db_string(option.Some(gender_to_match))),
    ],
    expecting: row.hippo_with_magic_row_decoder(),
  )
}

pub fn query_old_hippos_owner_names(
  conn: sqlight.Connection,
  min_age min_age: Int,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    old_hippos_owner_names_sql,
    on: conn,
    with: [sqlight.int(min_age)],
    expecting: row.hippo_with_magic_row_decoder(),
  )
}

pub fn query_old_hippos_owner_emails(
  conn: sqlight.Connection,
  min_age min_age: Int,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    old_hippos_owner_emails_sql,
    on: conn,
    with: [sqlight.int(min_age)],
    expecting: row.hippo_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited human rows.
pub fn last_100_edited_human(
  conn: sqlight.Connection,
) -> Result(List(#(hippo_schema.Human, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_human_sql,
    on: conn,
    with: [],
    expecting: row.human_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited hippo rows.
pub fn last_100_edited_hippo(
  conn: sqlight.Connection,
) -> Result(List(#(hippo_schema.Hippo, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_hippo_sql,
    on: conn,
    with: [],
    expecting: row.hippo_with_magic_row_decoder(),
  )
}
