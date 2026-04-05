import generators/api/api as api_generator
import generators/api/schema_context
import gleam/list
import gleam/string
import schema_definition/parser as schema_parser
import simplifile

pub fn item_id_variant_field_labels_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/additive_item_v1_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(e) =
    list.find(def.entities, fn(x) { x.type_name == "Item" })
  let id = schema_context.find_identity(def, e)
  let assert Ok(v) = list.first(id.variants)
  let labels = list.map(v.fields, fn(f) { f.label })
  let assert True = labels == ["name", "age"]
}

pub fn item_row_decoder_age_column_uses_int_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/additive_item_v1_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(out) =
    api_generator.generate_api_db_outputs("case_studies/additive_item_v1_schema", def)
  let assert True =
    string.contains(out.row, "use age <- decode.field(1, decode.int)")
}
