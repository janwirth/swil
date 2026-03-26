/// Catalogue of **mini Gleam modules** matching the shapes `schema_definition.parse_module` accepts.
///
/// **Suffix routing** (see `classify_strict`): a public type is classified by checking, in order, whether
/// its name ends with `Identities`, `Relationships`, `Attributes`, or `Scalar`; if none match, it is
/// parsed as an **entity**.
///
/// Spec summary (see `schema_definition` implementation for messages and edge cases):
///
/// 1. **`*Scalar`** — type name ends with `Scalar`; no `identities`; variants may be payload-free
///    (enum) or carry fields (record constructor).
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
/// 11. **Nullable primitives** — on entities (except `identities` / `relationships`), `*Relationships`,
///     and `*Attributes`, fields must not use bare `String` / `Int` / `Float` / `Bool` / `Date`; wrap
///     with `option.Option(...)`.
/// 12. **Magic row fields** — entity fields must not use the labels `id`, `created_at`, `updated_at`, or
///     `deleted_at` (see `dsl.MagicFields`); generated code supplies those.
///
import gleam/list
import gleam/string
import gleeunit
import schema_definition/query.{LtMissingFieldAsc}
import schema_definition/schema_definition as schema_definition
import simplifile

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

pub fn documented_shape_scalar_record_variant_parses_test() {
  let input =
    "import gleam/option

pub type ViewConfigScalar {
  ViewConfigScalar(
    filter_config: option.Option(String),
    source_selector: option.Option(String),
  )
}
"
  let assert Ok(def) = schema_definition.parse_module(input)
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
    "import gleam/option

pub type LinkAttributes {
  LinkAttributes(weight: option.Option(Int))
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
  case schema_definition.parse_module(input) {
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
  case schema_definition.parse_module(input) {
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
  case schema_definition.parse_module(input) {
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
  case schema_definition.parse_module(input) {
    Ok(_) ->
      panic as "expected entity fields reserved for dsl.MagicFields to be rejected"
    Error(_) -> Nil
  }
}

pub fn fruit_schema_query_infers_lt_missing_field_asc_test() {
  let assert Ok(src) = simplifile.read("src/case_studies/fruit_schema.gleam")
  let assert Ok(def) = schema_definition.parse_module(src)
  let assert [q] = def.queries
  assert q.name == "query_cheap_fruit"
  let assert LtMissingFieldAsc(
    column: "price",
    threshold_param: "max_price",
    shape_param: "fruit",
  ) = q.codegen
}
