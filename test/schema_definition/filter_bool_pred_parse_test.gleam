//// Unit tests for `schema_definition/query` extraction of `dsl.filter_bool` predicates
//// (boolean sublanguage: comparisons, `exclude_if_missing` / `age` / `nullable`, combinators).
////
//// Case-study sources: `fruit_schema` (`test/evolution/api/fruit.gleam`), `hippo_schema`
//// (`query_hippos_by_gender` at the line using `exclude_if_missing(hippo.gender) == gender_to_match`).

import gleam/list
import gleam/option.{Some}
import gleeunit
import schema_definition/parser as schema_parser
import schema_definition/schema_definition as sd
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

/// Helper function to get a query by name from a schema definition.
fn get_query_by_name(
  def: sd.SchemaDefinition,
  name: String,
) -> sd.QuerySpecDefinition {
  let assert Ok(q) =
    list.find(in: def.queries, one_that: fn(q) { q.name == name })
  q
}

fn assert_some_predicate(
  filter: option.Option(sd.Filter),
  inspect: fn(sd.Pred) -> Nil,
) {
  let assert Some(sd.Predicate(pred: pred)) = filter
  inspect(pred)
}

/// `fruit_schema`: `dsl.exclude_if_missing(fruit.price) <. max_price`
pub fn filter_bool_fruit_cheap_price_parse_test() {
  let assert Ok(src) = simplifile.read("test/case_studies/fruit_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let q = get_query_by_name(def, "query_cheap_fruit")
  assert_some_predicate(q.query.filter, fn(pred) {
    let assert sd.Compare(
      left: sd.Call(sd.ExcludeIfMissingFn, [sd.Field(path: price_path)]),
      operator: sd.Lt,
      right: sd.Param(name: "max_price"),
      missing_behavior: sd.ExcludeIfMissing,
    ) = pred
    assert price_path == ["fruit", "price"]
  })
}

/// `hippo_schema`: `exclude_if_missing(hippo.gender) == gender_to_match` (imported `exclude_if_missing`)
pub fn filter_bool_hippo_gender_eq_parse_test() {
  let assert Ok(src) = simplifile.read("test/case_studies/hippo_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let q = get_query_by_name(def, "query_hippos_by_gender")
  assert_some_predicate(q.query.filter, fn(pred) {
    let assert sd.Compare(
      left: sd.Call(sd.ExcludeIfMissingFn, [sd.Field(path: gender_path)]),
      operator: sd.Eq,
      right: sd.Param(name: "gender_to_match"),
      missing_behavior: sd.ExcludeIfMissing,
    ) = pred
    assert gender_path == ["hippo", "gender"]
  })
}

/// `hippo_schema`: `age(exclude_if_missing(hippo.date_of_birth)) > min_age`
pub fn filter_bool_hippo_age_gt_parse_test() {
  let assert Ok(src) = simplifile.read("test/case_studies/hippo_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let q = get_query_by_name(def, "query_old_hippos_owner_emails")
  assert_some_predicate(q.query.filter, fn(pred) {
    let assert sd.Compare(
      left: sd.Call(
        sd.AgeFn,
        [sd.Call(sd.ExcludeIfMissingFn, [sd.Field(path: dob_path)])],
      ),
      operator: sd.Gt,
      right: sd.Param(name: "min_age"),
      missing_behavior: sd.ExcludeIfMissing,
    ) = pred
    assert dob_path == ["hippo", "date_of_birth"]
  })
}

const not_filter_module = "import swil/dsl
import gleam/option

pub type Widget {
  Widget(flag: option.Option(Bool), identities: WidgetIdentities)
}

pub type WidgetIdentities {
  ByFlag(flag: Bool)
}

pub fn query_widget_active(w: Widget, _magic_fields: dsl.MagicFields, want: Bool) {
  dsl.query(w)
  |> dsl.shape(w)
  |> dsl.filter_bool(!{ dsl.exclude_if_missing(w.flag) == want })
  |> dsl.order(w.flag, dsl.Asc)
}
"

/// `!` on a comparison → `Pred.Not`
pub fn filter_bool_not_parse_test() {
  let assert Ok(def) = schema_parser.parse_module(not_filter_module)
  let q = get_query_by_name(def, "query_widget_active")
  assert_some_predicate(q.query.filter, fn(pred) {
    let assert sd.Not(item: inner) = pred
    let assert sd.Compare(
      left: sd.Call(sd.ExcludeIfMissingFn, [sd.Field(path: path)]),
      operator: sd.Eq,
      right: sd.Param(name: "want"),
      missing_behavior: sd.ExcludeIfMissing,
    ) = inner
    assert path == ["w", "flag"]
  })
}

const or_filter_module = "import swil/dsl
import gleam/option

pub type Duo {
  Duo(
    a: option.Option(Int),
    b: option.Option(Int),
    identities: DuoIdentities,
  )
}

pub type DuoIdentities {
  ByA(a: Int)
}

pub fn query_duo_any_above(d: Duo, _magic_fields: dsl.MagicFields, t: Int) {
  dsl.query(d)
  |> dsl.shape(d)
  |> dsl.filter_bool(
    dsl.exclude_if_missing(d.a) >. t || dsl.exclude_if_missing(d.b) >. t,
  )
  |> dsl.order(d.a, dsl.Asc)
}
"

/// `||` → `Pred.Or` with two `Compare` leaves
pub fn filter_bool_or_parse_test() {
  let assert Ok(def) = schema_parser.parse_module(or_filter_module)
  let q = get_query_by_name(def, "query_duo_any_above")
  assert_some_predicate(q.query.filter, fn(pred) {
    let assert sd.Or(items: items) = pred
    assert list.length(items) == 2
    let assert [c1, c2] = items
    let assert sd.Compare(
      left: sd.Call(sd.ExcludeIfMissingFn, [sd.Field(path: ["d", "a"])]),
      operator: sd.Gt,
      right: sd.Param(name: "t"),
      missing_behavior: sd.ExcludeIfMissing,
    ) = c1
    let assert sd.Compare(
      left: sd.Call(sd.ExcludeIfMissingFn, [sd.Field(path: ["d", "b"])]),
      operator: sd.Gt,
      right: sd.Param(name: "t"),
      missing_behavior: sd.ExcludeIfMissing,
    ) = c2
    Nil
  })
}
