import gleeunit
import generator.{generate, parse}
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"

  assert greeting == "Hello, Joe!"
}

pub fn hippo_skeleton_generation_test() {
  let assert Ok(schema_source) =
    simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(expected_skeleton) =
    simplifile.read("src/case_studies/hippo_db_skeleton.gleam")

  let generated_skeleton = schema_source |> parse |> generate(True)

  assert generated_skeleton == expected_skeleton
}
