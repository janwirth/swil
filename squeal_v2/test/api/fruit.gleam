import simplifile
import schema_definition
import generators/api/api
import assert_diff.{assert_diff}

pub fn fruit_api_generation_test () {
    let assert Ok(schema_src) =
    simplifile.read("src/case_studies/fruit_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/fruit_db/api.gleam")
  let assert Ok(def) = schema_definition.parse_module(schema_src)
  let generated = api.generate_api(def)
  assert_diff(expected, generated)

}