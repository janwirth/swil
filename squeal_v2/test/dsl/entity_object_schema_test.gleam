/// **Entity** (basic object / aggregate) rules: constructor name matches type, labelled fields,
/// required `identities: *Identities`, and that *Identities type must exist with `By…` variants.
import gleam/list
import gleeunit
import schema_definition/schema_definition as schema_definition

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn entity_object_must_have_identities_field_good_parses_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(name: option.Option(String), identities: RowIdentities)
}

pub type RowIdentities {
  ByName(name: String)
}
"
  let assert Ok(def) = schema_definition.parse_module(input)
  assert list.length(def.entities) == 1
  let assert [entity] = def.entities
  assert entity.identity_type_name == "RowIdentities"
  assert list.length(def.identities) == 1
}

pub fn entity_object_must_have_identities_field_bad_rejected_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(name: option.Option(String))
}
"
  case schema_definition.parse_module(input) {
    Ok(_) -> panic as "expected entity without identities field to be rejected"
    Error(_) -> Nil
  }
}

pub fn entity_object_identities_type_not_defined_rejected_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(name: option.Option(String), identities: RowIdentities)
}
"
  case schema_definition.parse_module(input) {
    Ok(_) ->
      panic as "expected entity referencing missing RowIdentities type to be rejected"
    Error(_) -> Nil
  }
}

pub fn entity_object_identities_type_defined_parses_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}
"
  let assert Ok(def) = schema_definition.parse_module(input)
  assert list.length(def.entities) == 1
  assert list.length(def.identities) == 1
  let assert [id] = def.identities
  assert id.type_name == "RowIdentities"
  let assert [variant] = id.variants
  assert variant.variant_name == "ByKey"
}

pub fn entity_object_identity_variant_must_start_with_by_rejected_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  WithKey(key: String)
}
"
  case schema_definition.parse_module(input) {
    Ok(_) ->
      panic as "expected identity variant not starting with By to be rejected"
    Error(_) -> Nil
  }
}
