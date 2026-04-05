/// **Public function** rules for `schema_definition.parse_module` (`query.extract_from_functions`).
///
/// Every **public** function must either:
/// - be a **`query_*`** query pipeline spec (`query |> shape |> filter |> order`, three typed parameters), or
/// - be a **`predicate_*`** helper with an explicit `-> dsl.BooleanFilter(...)` return (not emitted as a query spec).
///
/// Any other public function is rejected. Errors append
/// [`hint_public_function_prefixes`](schema_definition/parse_error.html#hint_public_function_prefixes)
/// (`query_` / `predicate_`).
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit
import schema_definition/parser as schema_parser
import schema_definition/schema_definition
import simplifile
import swil/dsl/dsl

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn documented_shape_query_tail_call_parses_test() {
  let input =
    "import swil/dsl/dsl as dsl
import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn query_by_key(row: Row, _magic: dsl.MagicFields, _k: Int) {
  dsl.query(row)
  |> dsl.shape(row)
  |> dsl.filter_bool(option.None)
  |> dsl.order(option.None, dsl.Desc)
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert list.length(def.queries) == 1
  let assert [q] = def.queries
  assert q.name == "query_by_key"
}

pub fn documented_shape_query_return_annotation_parses_test() {
  let input =
    "import swil/dsl/dsl as dsl
import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn query_by_key(row: Row, _magic: dsl.MagicFields, _k: Int) {
  dsl.query(row)
  |> dsl.shape(row)
  |> dsl.filter_bool(option.None)
  |> dsl.order(option.None, dsl.Desc)
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert list.length(def.queries) == 1
  let assert [q] = def.queries
  assert q.name == "query_by_key"
}

pub fn public_function_without_allowed_prefix_rejected_includes_hint_test() {
  let input =
    "import swil/dsl/dsl as dsl
import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn get_by_key(row: Row, _magic: dsl.MagicFields, _k: Int) {
  dsl.query(row)
  |> dsl.shape(row)
  |> dsl.filter_bool(option.None)
  |> dsl.order(option.None, dsl.Desc)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) -> panic as "expected disallowed public function name to be rejected"
    Error(e) -> {
      let msg = schema_parser.format_parse_error(input, e)
      assert string.contains(msg, "query_")
      assert string.contains(msg, "predicate_")
    }
  }
}

pub fn public_query_function_wrong_prefix_rejected_includes_hint_test() {
  let input =
    "import swil/dsl/dsl as dsl
import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn fetch_by_key(row: Row, _magic: dsl.MagicFields, _k: Int) {
  dsl.query(row)
  |> dsl.shape(row)
  |> dsl.filter_bool(option.None)
  |> dsl.order(option.None, dsl.Desc)
}
"
  case schema_parser.parse_module(input) {
    Ok(_) ->
      panic as "expected query-shaped public fn without query_ prefix to be rejected"
    Error(e) -> {
      let msg = schema_parser.format_parse_error(input, e)
      assert string.contains(msg, "query_")
      assert string.contains(msg, "predicate_")
    }
  }
}

pub fn public_predicate_boolean_filter_helper_parses_test() {
  let input =
    "import swil/dsl/dsl as dsl
import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn predicate_always_true(_row: Row) -> dsl.BooleanFilter(Int) {
  panic as \"dsl\"
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert def.queries == []
}

/// Mirrors `library_manager_schema_advanced` naming: `query_*` + `predicate_complex_tags_filter` with
/// `dsl.BooleanFilter` — full advanced query bodies (e.g. `complex_filter` in `filter`) are not inferred yet.
pub fn query_and_predicate_naming_mini_module_parses_test() {
  let input =
    "import swil/dsl/dsl as dsl
import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn query_rows(r: Row, _m: dsl.MagicFields, _x: Int) {
  dsl.query(r)
  |> dsl.shape(option.None)
  |> dsl.filter_bool(option.None)
  |> dsl.order(r, dsl.Asc)
}

pub fn predicate_complex_tags_filter(_r: Row) -> dsl.BooleanFilter(Int) {
  panic as \"dsl\"
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  assert list.length(def.queries) == 1
}

pub fn fruit_schema_query_infers_lt_missing_field_asc_test() {
  let assert Ok(src) = simplifile.read("test/case_studies/fruit_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert [q] = def.queries
  assert q.name == "query_cheap_fruit"
  let schema_definition.Query(shape: shape, filter: filter, order: order) =
    q.query
  assert shape == schema_definition.NoneOrBase
  let assert Some(schema_definition.Predicate(schema_definition.Compare(
    left: schema_definition.Call(
      func: schema_definition.ExcludeIfMissingFn,
      args: [schema_definition.Field(path: ["fruit", "price"])],
    ),
    operator: schema_definition.Lt,
    right: schema_definition.Param(name: "max_price"),
    missing_behavior: schema_definition.ExcludeIfMissing,
  ))) = filter
  assert order
    == schema_definition.CustomOrder(
      expr: schema_definition.Field(path: ["fruit", "price"]),
      direction: dsl.Asc,
    )
}
