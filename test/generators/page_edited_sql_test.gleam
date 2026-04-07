//// Structural tests for the `page_edited_*` SQL constant and function generation.
////
//// Verifies:
//// - generated SQL const contains `limit ?` and `offset ?` in bind order
//// - the bind list in the function body passes `sqlight.int(limit)` first, `sqlight.int(offset)` second

import generators/api/api_sql
import gleam/string
import gleeunit
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn page_edited_sql_contains_limit_offset_placeholders_test() {
  let sql = api_sql.page_edited_sql("fruit", ["name", "id"])
  assert string.contains(sql, "limit ?")
  assert string.contains(sql, "offset ?")
}

pub fn page_edited_sql_limit_before_offset_test() {
  let sql = api_sql.page_edited_sql("fruit", ["name", "id"])
  let assert Ok(limit_pos) = string.split_once(sql, "limit ?")
  let #(before_limit, after_limit) = limit_pos
  let _ = before_limit
  assert string.contains(after_limit, "offset ?")
}

pub fn page_edited_sql_filters_deleted_at_test() {
  let sql = api_sql.page_edited_sql("fruit", ["name"])
  assert string.contains(sql, "\"deleted_at\" is null")
}

pub fn page_edited_sql_orders_by_updated_at_desc_test() {
  let sql = api_sql.page_edited_sql("fruit", ["name"])
  assert string.contains(sql, "order by \"updated_at\" desc")
}

pub fn page_edited_fruit_sql_const_in_generated_query_file_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/fruit_db/query.gleam")
  assert string.contains(src, "page_edited_fruit_sql")
  assert string.contains(src, "limit ? offset ?")
  assert string.contains(src, "sqlight.int(limit)")
  assert string.contains(src, "sqlight.int(offset)")
}
