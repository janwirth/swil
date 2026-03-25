import gleeunit
import schema_definition
import simplifile
import skeleton_generator

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn hippo_db_skeleton_exact_match_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/hippo_db_skeleton.gleam")

  let assert Ok(def) = schema_definition.parse_module(schema_src)

  let generated =
    skeleton_generator.generate("case_studies/hippo_schema", def)

  assert generated == expected
}
