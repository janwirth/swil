import generators/api/api
import gleam/string
import schema_definition/parser as schema_parser
import simplifile

pub fn update_by_id_emitted_for_all_entities_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/library_manager_advanced_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)
  let assert Ok(out) =
    api.generate_api_db_outputs("case_studies/library_manager_advanced_schema", def)

  assert string.contains(out.upsert, "const update_tag_by_id_sql")
  assert string.contains(
    out.upsert,
    "set \\\"label\\\" = ?, \\\"emoji\\\" = ?, \\\"updated_at\\\" = ? where \\\"id\\\" = ?",
  )
  assert string.contains(out.upsert, "let db_label = api_help.opt_text_for_db(label)")
  assert string.contains(out.upsert, "pub fn update_tag_by_id(")
  assert string.contains(
    out.upsert,
    "not_found_tag_id_error(\"update_tag_by_id\")",
  )
  assert string.contains(out.api, "pub fn update_tag_by_id(")
  assert string.contains(out.api, "upsert.update_tag_by_id(conn, id, label, emoji)")

  assert string.contains(out.upsert, "const update_tab_by_id_sql")
  assert string.contains(out.upsert, "pub fn update_tab_by_id(")

  assert string.contains(out.upsert, "const update_importedtrack_by_id_sql")
  assert string.contains(out.upsert, "pub fn update_importedtrack_by_id(")
}
