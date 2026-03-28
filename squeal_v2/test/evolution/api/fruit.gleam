import assert_diff.{assert_diff}
import generators/api/api
import gleam/string
import schema_definition/parser as schema_parser
import simplifile

fn collapse_extra_blank_lines(s: String) -> String {
  case string.contains(s, "\n\n\n") {
    True ->
      collapse_extra_blank_lines(string.replace(s, "\n\n\n", "\n\n"))
    False -> s
  }
}

pub fn fruit_api_generation_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/fruit_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)
  let out = api.generate_api_db_outputs("case_studies/fruit_schema", def)
  let norm = fn(s: String) {
    string.trim_end(s)
    |> collapse_extra_blank_lines
    <> "\n"
  }
  let read = fn(path: String) {
    let assert Ok(s) = simplifile.read(path)
    norm(s)
  }
  assert_diff(read("src/case_studies/fruit_db/api.gleam"), norm(out.api))
  assert_diff(read("src/case_studies/fruit_db/row.gleam"), norm(out.row))
  assert_diff(read("src/case_studies/fruit_db/get.gleam"), norm(out.get))
  assert_diff(read("src/case_studies/fruit_db/upsert.gleam"), norm(out.upsert))
  assert_diff(read("src/case_studies/fruit_db/delete.gleam"), norm(out.delete))
  assert_diff(read("src/case_studies/fruit_db/query.gleam"), norm(out.query))
}
