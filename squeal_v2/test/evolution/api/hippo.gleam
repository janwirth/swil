import assert_diff.{assert_diff}
import generators/api/api
import gleam/string
import schema_definition/schema_definition as schema_definition
import simplifile

pub fn hippo_api_generation_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(def) = schema_definition.parse_module(schema_src)
  let out = api.generate_api_db_outputs("case_studies/hippo_schema", def)
  let norm = fn(s: String) {
    string.trim_end(s) <> "\n"
  }
  let read = fn(path: String) {
    let assert Ok(s) = simplifile.read(path)
    norm(s)
  }
  assert_diff(read("src/case_studies/hippo_db/api.gleam"), norm(out.api))
  assert_diff(read("src/case_studies/hippo_db/row.gleam"), norm(out.row))
  assert_diff(read("src/case_studies/hippo_db/upsert.gleam"), norm(out.upsert))
  assert_diff(read("src/case_studies/hippo_db/delete.gleam"), norm(out.delete))
  assert_diff(read("src/case_studies/hippo_db/query.gleam"), norm(out.query))
}
