import case_studies/hippo_db/row
import dsl/dsl as dsl
import case_studies/hippo_schema.{type HumanRelationships, type Human, type HippoRelationships, type Hippo, type GenderScalar, Male, HumanRelationships, Human, HippoRelationships, Hippo, Female, ByNameAndDateOfBirth, ByEmail}
import gleam/result
import sqlight

const last_100_sql = "select \"name\", \"gender\", \"date_of_birth\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"hippo\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// List up to 100 recently edited hippo rows.
pub fn last_100_edited_hippo(
  conn: sqlight.Connection,
) -> Result(List(#(Hippo, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_sql,
    on: conn,
    with: [],
    expecting: row.hippo_with_magic_row_decoder(),
  )
}
