import generators/api/api
import gleam/string
import schema_definition/parser as schema_parser
import simplifile

/// Generated `cmd.gleam` exposes `Patch*` variants with dynamic `UPDATE` SQL (`string.join` + `list.reverse`).
pub fn fruit_cmd_emits_patch_variants_test() {
  let assert Ok(schema_src) =
    simplifile.read("test/case_studies/fruit_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)
  let assert Ok(out) =
    api.generate_api_db_outputs("case_studies/fruit_schema", def)

  assert string.contains(out.cmd, "PatchFruitByName(")
  assert string.contains(out.cmd, "PatchFruitById(")
  assert string.contains(out.cmd, "string.join(list.reverse(set_parts)")
  assert string.contains(out.cmd, "option.None -> #(set_parts, binds)")
}
