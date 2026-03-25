import gleeunit
import case_studies/hippo_db_skeleton as hippo_db
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

pub fn hippo_skeleton_api_consumer_completeness_test() {
  // Compile-time consumer check: public API symbols exist with callable types.
  let _ = hippo_db.upsert_human_by_email
  let _ = hippo_db.delete_human_by_email
  let _ = hippo_db.delete_human_by_id
  let _ = hippo_db.query_old_hippos_owner_emails
  let _ = hippo_db.query_hippos_by_gender
  let _ = hippo_db.upsert_hippo

  // Also assert public output constructors are exported for consumers.
  let _ = hippo_db.QueryOldHipposOwnerEmailsResult
  let _ = hippo_db.QueryOldHipposOwnerEmailsResultOwner
  let _ = hippo_db.HipposByGenderResult
}
