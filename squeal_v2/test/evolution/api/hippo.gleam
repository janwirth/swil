import assert_diff.{assert_diff}
import generators/api/api
import schema_definition/schema_definition as schema_definition
import simplifile

pub fn hippo_api_generation_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/hippo_db/api.gleam")
  let assert Ok(def) = schema_definition.parse_module(schema_src)
  let generated = api.generate_api("case_studies/hippo_schema", def)
  assert_diff(expected, generated)
}
