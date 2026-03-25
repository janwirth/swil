/// Catalogue of **mini Gleam modules** matching the shapes `schema_definition.parse_module` accepts.
///
/// Spec summary (see `schema_definition` implementation for messages and edge cases):
///
/// 1. **Scalar enum** — every variant is payload-free; at least one variant; type name ends with `Scalar`.
/// 2. **`*Identities`** — type name ends with `Identities`; variants named `By…`; labelled fields only; must be the `identities` field on a public entity in the same module.
/// 3. **Entity** — one variant; constructor name equals the type name; labelled fields only;
///    required `identities: …` with a simple type name ending in `Identities`;
///    optional `relationships: …` with a simple type name ending in `Relationships`.
///    See `entity_object_schema_test` for entity / identities edge cases.
/// 4. **`*Relationships`** — one variant named like the type; labelled fields only.
/// 5. **`*Attributes`** — one variant named like the type; labelled fields only.
/// 6. **Public `pub fn` query specs** — every public function must return `Query` (annotated or tail
///    `Query(...)`); parameters must have type annotations.
/// 7. **No type parameters** on public custom types in schema modules.
/// 8. **No zero-variant public types** (add variants or use `private`).
/// 9. **Private** `type` definitions are not validated as schema shapes.
/// 10. **Walk order** is source order (Glance’s definition lists are reversed before folding).
///
import gleam/list
import gleam/string
import gleeunit
import schema_definition

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
  let assert Ok(def) = schema_definition.parse_module(input)
  assert def.entities == []
  assert def.identities == []
  assert list.length(def.scalars) == 1
  let assert [scalar] = def.scalars
  assert scalar.type_name == "StatusScalar"
  assert list.sort(scalar.variant_names, string.compare) == ["Off", "On"]
}

pub fn standalone_identities_without_entity_rejected_test() {
  let input =
    "pub type RowIdentities {
  ByName(name: String)
  ById(id: Int)
}
"
  case schema_definition.parse_module(input) {
    Ok(_) ->
      panic as "expected *Identities type without a referencing entity to be rejected"
    Error(_) -> Nil
  }
}

pub fn documented_shape_entity_with_relationships_parses_test() {
  let input =
    "import gleam/option

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
  let assert Ok(def) = schema_definition.parse_module(input)
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
  let assert Ok(def) = schema_definition.parse_module(input)
  assert def.entities == []
  assert list.length(def.relationship_containers) == 1
  let assert [rel] = def.relationship_containers
  assert rel.type_name == "RowRelationships"
}

pub fn documented_shape_edge_attributes_only_parses_test() {
  let input =
    "pub type LinkAttributes {
  LinkAttributes(weight: Int)
}
"
  let assert Ok(def) = schema_definition.parse_module(input)
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
  let assert Ok(def) = schema_definition.parse_module(input)
  assert def.entities == []
  assert def.identities == []
  assert list.length(def.scalars) == 1
  let assert [scalar] = def.scalars
  assert scalar.type_name == "StatusScalar"
}

pub fn documented_shape_query_tail_call_parses_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn by_key(k: Int) {
  Query(shape: option.None, filter: option.None, order: option.None)
}
"
  let assert Ok(def) = schema_definition.parse_module(input)
  assert list.length(def.queries) == 1
  let assert [q] = def.queries
  assert q.name == "by_key"
}

pub fn documented_shape_query_return_annotation_parses_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn by_key(k: Int) -> Query {
  Query(shape: option.None, filter: option.None, order: option.None)
}
"
  let assert Ok(def) = schema_definition.parse_module(input)
  assert list.length(def.queries) == 1
  let assert [q] = def.queries
  assert q.name == "by_key"
}

pub fn generic_custom_type_rejected_test() {
  let input =
    "pub type Box(a) {
  Box(value: Int)
}
"
  let output = schema_definition.parse_module(input)
  case output {
    Ok(_) ->
      panic as "expected generic custom type module to be rejected by parse_module"
    Error(_) -> Nil
  }
}
