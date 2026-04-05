import generators/api/api
import gleam/string
import schema_definition/parser as schema_parser
import simplifile

pub fn update_by_id_emitted_for_all_entities_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/library_manager_advanced_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)
  let assert Ok(out) =
    api.generate_api_db_outputs(
      "case_studies/library_manager_advanced_schema",
      def,
    )

  assert string.contains(out.cmd, "const tag_update_by_id_sql")
  assert string.contains(
    out.cmd,
    "set \\\"label\\\" = ?, \\\"emoji\\\" = ?, \\\"updated_at\\\" = ? where \\\"id\\\" = ?",
  )
  assert string.contains(out.cmd, "UpdateTagById(")
  assert string.contains(out.cmd, "pub fn execute_tag_cmds(")

  assert string.contains(out.cmd, "const tab_update_by_id_sql")
  assert string.contains(out.cmd, "UpdateTabById(")

  assert string.contains(out.cmd, "const importedtrack_update_by_id_sql")
  assert string.contains(out.cmd, "UpdateImportedTrackById(")

  assert string.contains(out.api, "pub fn execute_tag_cmds(")
  assert string.contains(
    out.api,
    "cmd.execute_tag_cmds(conn, commands)",
  )
  assert !string.contains(out.api, "pub type TagUpsertRow")
  assert !string.contains(out.api, "pub fn upsert_one_tag(")
  assert !string.contains(out.api, "by_tag_tag_label")
}
