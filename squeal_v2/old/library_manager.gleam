import assert_diff.{assert_diff}
import generators/api/api
import gleam/string
import schema_definition/parser as schema_parser
import schema_definition/schema_definition
import simplifile

pub fn library_manager_api_generation_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/library_manager_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/library_manager_db/api.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)
  let generated = api.generate_api("case_studies/library_manager_schema", def)
  let norm = fn(s: String) { string.trim_end(s) <> "\n" }
  assert_diff(norm(expected), norm(generated))
}
