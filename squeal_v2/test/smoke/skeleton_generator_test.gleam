// this makes sure we get the general sturcute, types, naming etc. right after generation

import assert_diff.{assert_diff}
import gleeunit
import schema_definition/schema_definition as schema_definition
import simplifile
import generators/skeleton as skeleton_generator

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn hippo_db_skeleton_exact_match_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/hippo_db_skeleton.gleam")
  let assert Ok(def) = schema_definition.parse_module(schema_src)

  let generated = skeleton_generator.generate("case_studies/hippo_schema", def)

  assert_diff(expected, generated)
}

pub fn fruit_db_skeleton_exact_match_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/fruit_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/fruit_db/skeleton.gleam")
  let assert Ok(def) = schema_definition.parse_module(schema_src)

  let generated = skeleton_generator.generate("case_studies/fruit_schema", def)
  assert_diff(expected, generated)
}

pub fn library_manager_db_skeleton_exact_match_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/library_manager_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/library_manager_db_skeleton.gleam")
  let assert Ok(def) = schema_definition.parse_module(schema_src)

  let generated =
    skeleton_generator.generate("case_studies/library_manager_schema", def)
  assert_diff(expected, generated)
}
