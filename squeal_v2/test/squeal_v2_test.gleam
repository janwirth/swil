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
