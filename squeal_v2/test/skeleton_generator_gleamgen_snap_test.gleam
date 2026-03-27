import assert_diff.{assert_diff}
import generators/skeleton as skeleton_generator
import gleeunit
import schema_definition/parser as schema_parser
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn gleamgen_hippo_db_skeleton_exact_match_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/hippo_db/skeleton.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)

  let generated = skeleton_generator.generate("case_studies/hippo_schema", def)
  //   simplifile.write("src/case_studies/hippo_db_skeleton.gleam", generated)

  assert_diff(expected, generated)
}

pub fn gleamgen_fruit_db_skeleton_exact_match_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/fruit_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/fruit_db/skeleton.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)

  let generated = skeleton_generator.generate("case_studies/fruit_schema", def)
  // simplifile.write("src/case_studies/fruit_db/skeleton.gleam", generated)
  assert_diff(expected, generated)
}

pub fn gleamgen_library_manager_db_skeleton_exact_match_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/library_manager_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("src/case_studies/library_manager_db_skeleton.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)

  let generated =
    skeleton_generator.generate("case_studies/library_manager_schema", def)
  // let assert Ok(Nil) =
  //   simplifile.write(
  //     "src/case_studies/library_manager_db_skeleton.gleam",
  //     generated,
  //   )
  assert_diff(expected, generated)
}
