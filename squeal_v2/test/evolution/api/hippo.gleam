import assert_diff.{assert_diff}
import generators/api/api
import gleam/string
import schema_definition/parser as schema_parser
import simplifile

pub fn hippo_api_generation_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)
  let out = api.generate_api_db_outputs("case_studies/hippo_schema", def)
  let norm = fn(s: String) { string.trim_end(s) <> "\n" }
  let read = fn(path: String) {
    let assert Ok(s) = simplifile.read(path)
    norm(s)
  }
  assert_diff(read("src/case_studies/hippo_db/api.gleam"), norm(out.api))
  assert_diff(read("src/case_studies/hippo_db/row.gleam"), norm(out.row))
  assert_diff(read("src/case_studies/hippo_db/get.gleam"), norm(out.get))
  assert_diff(read("src/case_studies/hippo_db/delete.gleam"), norm(out.delete))
  // `upsert.gleam` and `query.gleam` intentionally include hand-written
  // relationship helpers used by the hippo relationship e2e scenario.
}
