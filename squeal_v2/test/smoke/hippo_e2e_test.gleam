import case_studies/hippo_db_skeleton as hippo_db
import case_studies/hippo_schema
import gleam/option
import gleam/time/calendar.{type Date}
import schema_definition
import skeleton_generator
import gleeunit
import simplifile
import sqlight

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn hippo_skeleton_generation_test() {
  let assert Ok(schema_source) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(expected_skeleton) =
    simplifile.read("src/case_studies/hippo_db_skeleton.gleam")

  let assert Ok(def) = schema_definition.parse_module(schema_source)
  let generated_skeleton =
    skeleton_generator.generate("case_studies/hippo_schema", def)

  assert generated_skeleton == expected_skeleton
}

pub fn hippo_skeleton_api_consumer_completeness_test() {
  // Compile-time check: public API types stay in sync with consumers (bodies
  // remain `todo` in the golden skeleton).
  let _: fn(sqlight.Connection) -> Result(Nil, sqlight.Error) = hippo_db.migrate
  let _: fn(sqlight.Connection, String, option.Option(String)) -> Result(
    hippo_schema.Human,
    sqlight.Error,
  ) = hippo_db.upsert_human_by_email
  let _: fn(
    sqlight.Connection,
    hippo_schema.GenderScalar,
  ) -> Result(
    List(hippo_db.HipposByGenderResult),
    sqlight.Error,
  ) = hippo_db.query_hippos_by_gender
  let _: fn(
    sqlight.Connection,
    String,
    Date,
    option.Option(hippo_schema.GenderScalar),
  ) -> Result(hippo_schema.Hippo, sqlight.Error) =
    hippo_db.upsert_hippo_by_name_and_date_of_birth
}
