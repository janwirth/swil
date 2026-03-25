import case_studies/hippo_db_skeleton as hippo_db
import case_studies/hippo_schema
import generator.{generate, parse}
import gleam/option
import gleam/time/calendar
import gleeunit
import simplifile
import sqlight

pub fn main() -> Nil {
  gleeunit.main()
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
  let assert Ok(conn) = sqlight.open("hippo.db")
  // Compile-time consumer check: public API symbols exist with callable types.
  let assert Ok(_) = hippo_db.migrate(conn)
  // multiple migrations should be idempotent
  let assert Ok(_) = hippo_db.migrate(conn)

  let assert Ok(girl) =
    hippo_db.upsert_hippo_by_name_and_date_of_birth(
      conn,
      "Test Hippo",
      calendar.Date(year: 2020, month: calendar.February, day: 1),
      option.Some(hippo_schema.Female),
    )
  let assert Ok(boy) =
    hippo_db.upsert_hippo_by_name_and_date_of_birth(
      conn,
      "Test Hippo",
      calendar.Date(year: 2020, month: calendar.February, day: 1),
      option.Some(hippo_schema.Male),
    )

  let assert Ok(human) =
    hippo_db.upsert_human_by_email(
      conn,
      "test@example.com",
      option.Some("Test User"),
    )
  let assert Ok([one]) =
    hippo_db.query_hippos_by_gender(conn, hippo_schema.Male)
  let assert Ok(_) = hippo_db.delete_human_by_email(conn, "test@example.com")

  sqlight.close(conn)
}
