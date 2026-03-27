//// **Entity** (basic object / aggregate) rules: constructor name matches type, labelled fields,
//// required `identities: *Identities`, and that *Identities type must exist with `By…` variants.
////
//// ## Public `query_*` parameter contract (target for simpler query generation)
////
//// Every `query_*` function will declare **exactly three** user-facing parameters, in this order:
////
//// 1. **Entity** — A parameter typed as a **public entity** from the same schema module (e.g. `fruit: Fruit`).
////    That type must be one of the module’s parsed entities (constructor matches `pub type` name).
////
//// 2. **`dsl.MagicFields`** — Second parameter is typed as `dsl.MagicFields` (generated row metadata:
////    `id`, timestamps, soft delete). If the query body does not use those fields, satisfy the contract with
////    **discards** when you match on `magic` — e.g.
////    `let dsl.MagicFields(id: _, created_at: _, updated_at: _, deleted_at: _) = magic` — or equivalent
////    patterns so each magic slot is explicitly unused.
////
//// 3. **One simple parameter** — Exactly one more argument whose type is a `QuerySimpleType` (`Int`,
////    `Float`, `Bool`, `String` for now). Used for thresholds, limits, and SQL bind parameters.
////
//// Example target signature:
////
//// ```gleam
//// pub fn query_cheap_fruit(
////   fruit: Fruit,
////   magic: dsl.MagicFields,
////   max_price: Float,
//// ) {
////   let dsl.MagicFields(id: _, created_at: _, updated_at: _, deleted_at: _) = magic
////   ...
//// }
//// ```
////
//// The structured form of these three slots is `schema_definition.QueryFunctionParameters` (re-exported types
//// from `schema_definition/query_params.gleam`).

import gleam/list
import gleeunit
import schema_definition/parser as schema_parser
import schema_definition/query_params as qp

pub fn main() -> Nil {
  gleeunit.main()
}

/// Golden structural encoding for a fruit “cheap price” query once params are reordered (entity → magic → float).
pub fn query_function_parameters_fruit_example_test() {
  let contract =
    qp.QueryFunctionParameters(
      entity: qp.QueryEntityParameter("fruit", "Fruit"),
      magic_fields: qp.QueryMagicFieldsParameter(
        // Binding name in source; discards apply to fields inside MagicFields, not this name.
        "magic",
      ),
      simple: qp.QuerySimpleParameter("max_price", qp.QuerySimpleFloat),
    )
  assert contract.entity.type_name == "Fruit"
  assert contract.simple.type_ == qp.QuerySimpleFloat
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
  let assert Ok(def) = schema_parser.parse_module(input)
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
  case schema_parser.parse_module(input) {
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
  case schema_parser.parse_module(input) {
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
  let assert Ok(def) = schema_parser.parse_module(input)
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
  case schema_parser.parse_module(input) {
    Ok(_) ->
      panic as "expected identity variant not starting with By to be rejected"
    Error(_) -> Nil
  }
}

pub fn entity_object_query_function_must_start_with_query_prefix_rejected_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn by_key(k: Int) {
  query(Row(identities: RowIdentities.ByKey(key: \"\")))
  |> shape(option.None)
  |> filter(option.None)
  |> order(option.None)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) ->
      panic as "expected query function without query_ prefix to be rejected"
    Error(_) -> Nil
  }
}

pub fn entity_object_query_function_with_let_statement_rejected_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn query_by_key(row: Row, _magic: dsl.MagicFields, k: Int) {
  let x = k
  query(row)
  |> shape(row)
  |> filter(x > 0)
  |> order(option.None)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) ->
      panic as "expected query function containing let statement to be rejected"
    Error(_) -> Nil
  }
}

pub fn entity_object_filter_function_must_start_with_filter_prefix_rejected_test() {
  let input =
    "import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn helper_filter(row: Row) -> BooleanFilter {
  Predicate(value: True)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) ->
      panic as "expected BooleanFilter helper without filter_ prefix to be rejected"
    Error(_) -> Nil
  }
}
