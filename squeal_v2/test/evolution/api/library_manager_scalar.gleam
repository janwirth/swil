import generators/api/api
import gleam/string
import schema_definition/parser as schema_parser
import simplifile

pub fn library_manager_non_enum_scalar_codegen_test() {
  let assert Ok(schema_src) =
    simplifile.read("src/case_studies/library_manager_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(schema_src)
  let assert Ok(out) =
    api.generate_api_db_outputs("case_studies/library_manager_schema", def)

  assert string.contains(out.row, "fn view_config_scalar_json_decoder()")
  assert string.contains(out.row, "view_config_scalar_from_db_string")
  assert string.contains(
    out.row,
    "Result(option.Option(library_manager_schema.ViewConfigScalar), String)",
  )
  assert string.contains(out.row, "json.parse(")
  assert string.contains(
    out.row,
    "decode.optional(view_config_scalar_json_decoder())",
  )
  assert string.contains(
    out.row,
    "decode.failure(option.None, expected: \"Option(ViewConfigScalar)\")",
  )
}
