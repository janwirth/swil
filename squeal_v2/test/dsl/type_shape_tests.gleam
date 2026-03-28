/// **Public type** shapes accepted by `schema_definition.parse_module`.
///
/// **Suffix routing** (`classify_strict`): a public type is classified by checking, in order, whether its name
/// ends with `Identities`, `Relationships`, `Attributes`, or `Scalar`; if none match, it is parsed as an
/// **entity** (single variant + `identities` field). Any other shape is rejected; diagnostics append
/// [`hint_public_type_suffixes_or_entity`](schema_definition/parse_error.html#hint_public_type_suffixes_or_entity).
///
/// 1. **`*Scalar`** — name ends with `Scalar`; variants enum or record.
/// 2. **`*Identities`** — ends with `Identities`; `By…` variants; must be referenced from an entity’s `identities`.
/// 3. **Entity** — otherwise: one record variant named like the type + `identities: *Identities`.
/// 4. **`*Relationships`** / **`*Attributes`** — container shapes as documented in `schema_shapes` history.
/// 5. **No type parameters** on public custom types; **no zero-variant** public types.
/// 6. **Private** types are not validated as schema shapes.
/// 7. **Nullable primitives** on entities / relationship / attribute types (see other tests).
/// 8. **Magic row field labels** reserved on entities.
import gleam/list
import gleam/string
import gleeunit
import schema_definition/parser as schema_parser

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn documented_shape_scalar_enum_parses_test() {
  let input =
    "pub type StatusScalar {
  On
  Off
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert def.entities == []
  assert def.identities == []
  assert list.length(def.scalars) == 1
  let assert [scalar] = def.scalars
  assert scalar.type_name == "StatusScalar"
  assert list.sort(scalar.variant_names, string.compare) == ["Off", "On"]
}

pub fn documented_shape_scalar_record_variant_parses_test() {
  let input =
    "import dsl/dsl as dsl
import gleam/option

pub type ViewConfigScalar {
  ViewConfigScalar(
    filter_config: option.Option(String),
    source_selector: option.Option(String),
  )
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert def.entities == []
  assert def.identities == []
  assert def.relationship_edge_attributes == []
  assert list.length(def.scalars) == 1
  let assert [scalar] = def.scalars
  assert scalar.type_name == "ViewConfigScalar"
  assert scalar.variant_names == ["ViewConfigScalar"]
}

pub fn standalone_identities_without_entity_rejected_test() {
  let input =
    "pub type RowIdentities {
  ByName(name: String)
  ById(id: Int)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) ->
      panic as "expected *Identities type without a referencing entity to be rejected"
    Error(_) -> Nil
  }
}

pub fn documented_shape_entity_with_relationships_parses_test() {
  let input =
    "import dsl/dsl as dsl
import gleam/option

pub type Row {
  Row(
    name: option.Option(String),
    identities: RowIdentities,
    relationships: RowRelationships,
  )
}

pub type RowIdentities {
  ByName(name: String)
}

pub type RowRelationships {
  RowRelationships(peer: option.Option(String))
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert list.length(def.entities) == 1
  assert list.length(def.identities) == 1
  assert list.length(def.relationship_containers) == 1
  let assert [rel] = def.relationship_containers
  assert rel.type_name == "RowRelationships"
}

pub fn documented_shape_relationships_container_only_parses_test() {
  let input =
    "import gleam/option

pub type RowRelationships {
  RowRelationships(peer: option.Option(String))
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert def.entities == []
  assert list.length(def.relationship_containers) == 1
  let assert [rel] = def.relationship_containers
  assert rel.type_name == "RowRelationships"
}

pub fn documented_shape_edge_attributes_only_parses_test() {
  let input =
    "import gleam/option

pub type LinkAttributes {
  LinkAttributes(weight: option.Option(Int))
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert list.length(def.relationship_edge_attributes) == 1
  let assert [attrs] = def.relationship_edge_attributes
  assert attrs.type_name == "LinkAttributes"
}

pub fn documented_shape_private_type_ignored_parses_test() {
  let input =
    "type Secret {
  Secret(x: Int)
}

pub type StatusScalar {
  On
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert def.entities == []
  assert def.identities == []
  assert list.length(def.scalars) == 1
  let assert [scalar] = def.scalars
  assert scalar.type_name == "StatusScalar"
}

pub fn generic_custom_type_rejected_test() {
  let input =
    "pub type Box(a) {
  Box(value: Int)
}
"
  let output = schema_parser.parse_module(input)
  case output {
    Ok(_) ->
      panic as "expected generic custom type module to be rejected by parse_module"
    Error(_) -> Nil
  }
}

pub fn entity_non_nullable_primitive_field_rejected_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(title: String, identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) -> panic as "expected entity field with bare String to be rejected"
    Error(_) -> Nil
  }
}

pub fn relationship_container_non_nullable_primitive_field_rejected_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub type RowRelationships {
  RowRelationships(peer: String)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) ->
      panic as "expected *Relationships field with bare String to be rejected"
    Error(_) -> Nil
  }
}

pub fn edge_attributes_non_nullable_primitive_field_rejected_test() {
  let input =
    "import gleam/option

pub type LinkAttributes {
  LinkAttributes(weight: Int)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) -> panic as "expected *Attributes field with bare Int to be rejected"
    Error(_) -> Nil
  }
}

pub fn entity_magic_field_labels_rejected_test() {
  let input =
    "import gleam/option
import gleam/time/timestamp

pub type Row {
  Row(
    id: option.Option(Int),
    created_at: timestamp.Timestamp,
    updated_at: timestamp.Timestamp,
    identities: RowIdentities,
  )
}

pub type RowIdentities {
  ByKey(key: String)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) ->
      panic as "expected entity fields reserved for dsl.MagicFields to be rejected"
    Error(_) -> Nil
  }
}

pub fn public_type_neither_entity_nor_suffix_rejected_includes_hint_test() {
  let input =
    "pub type Weird {
  Weird(x: Int)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) -> panic as "expected invalid public type to be rejected"
    Error(e) -> {
      let msg = schema_parser.format_parse_error(input, e)
      assert string.contains(msg, "Scalar")
      assert string.contains(msg, "Identities")
    }
  }
}
