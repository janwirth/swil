import gleam/list
import gleam/option.{type Option, Some}
import gleam/time/calendar.{type Date}
import gleam/time/timestamp.{type Timestamp}

// these functions implementations are expanded into individual queries when done
// idempotent migrations _may_ work

pub fn age(t: Date) -> Int {
  todo("Implement on SQL level")
}

pub type Mutual(a, attributes) {
  Mutual(item: a)
  // maps to same field
}

pub type MutualWith(a, attributes) {
  MutualWith(item: a, attributes: Option(attributes))
}

pub type BelongsTo(a) {
  BelongsTo(item: a)
}

pub type BelongsToWith(a, attributes) {
  BelongsToWith(item: a, attributes: Option(attributes))
}

pub type Backlink(kind) {
  Backlink(items: List(kind))
}

pub type BacklinkWith(kind, attributes) {
  BacklinkWith(items: List(kind), attributes: Option(attributes))
}

pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
  todo
}

pub fn nullable(some_val: option.Option(some_type)) -> some_type {
  todo
}

// then it generates a query that just writes sql amd has a decoder for the right fields

// pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
//     todo
// }
// it's just querying that needs new generators.... Maybe it's better to just generate the plain values

// use proper migrations?
// o

// composing queries
pub type Query(type_, shape, order_field) {
  Query(shape: shape, filter: Option(Bool), order: #(order_field, Direction))
}

pub type MagicFields {
  MagicFields(
    id: Int,
    created_at: Timestamp,
    updated_at: Timestamp,
    deleted_at: Option(Timestamp),
  )
}

pub type Direction {
  Asc
  Desc
}

pub fn order_by(field: field, direction: Direction) -> #(field, Direction) {
  #(field, direction)
}

pub type BooleanFilter {
  And(
    exprs: List(BooleanFilter)
  )
  Or(
    exprs: List(BooleanFilter)
  )
  Not(
    expr: BooleanFilter
  )
  /// `(tag_row_id, weight)` pairs (in-memory / UI until SQL expands this).
  TagAssocHas(assoc: List(#(Int, Int)), tag_id: Int)
  TagAssocNotHas(assoc: List(#(Int, Int)), tag_id: Int)
  TagAssocCompare(
    assoc: List(#(Int, Int)),
    tag_id: Int,
    pred: WithPredicate,
  )
}

pub fn has(field: List(#(Int, Int)), tag_id: Int) -> BooleanFilter {
  TagAssocHas(field, tag_id)
}

pub fn not_has(field: List(#(Int, Int)), tag_id: Int) -> BooleanFilter {
  TagAssocNotHas(field, tag_id)
}

pub fn has_with(
  field: List(#(Int, Int)),
  related_id: Int,
  predicate: WithPredicate,
) -> BooleanFilter {
  TagAssocCompare(field, related_id, predicate)
}

pub type WithPredicate {
  AtLeast(value: Int)
  AtMost(value: Int)
  EqualTo(value: Int)
}

pub fn is_at_least(value: Int) -> WithPredicate {
  AtLeast(value)
}

pub fn is_at_most(value: Int) -> WithPredicate {
  AtMost(value)
}

pub fn is_equal_to(value: Int) -> WithPredicate {
  EqualTo(value)
}

fn pred_satisfied(weight: Int, pred: WithPredicate) -> Bool {
  case pred {
    AtLeast(n) -> weight >= n
    AtMost(n) -> weight <= n
    EqualTo(n) -> weight == n
  }
}

pub fn eval_boolean_filter(filter: BooleanFilter) -> Bool {
  case filter {
    And(exprs) ->
      case exprs {
        [] -> True
        _ -> list.all(exprs, eval_boolean_filter)
      }
    Or(exprs) ->
      case exprs {
        [] -> False
        _ -> list.any(exprs, eval_boolean_filter)
      }
    Not(expr) -> !eval_boolean_filter(expr)
    TagAssocHas(assoc, tag_id) ->
      list.any(assoc, fn(p) {
        let #(id, _) = p
        id == tag_id
      })
    TagAssocNotHas(assoc, tag_id) ->
      !list.any(assoc, fn(p) {
        let #(id, _) = p
        id == tag_id
      })
    TagAssocCompare(assoc, tag_id, pred) ->
      case list.find(assoc, fn(p) { p.0 == tag_id }) {
        Ok(#(_, w)) -> pred_satisfied(w, pred)
        Error(Nil) -> False
      }
  }
}

pub fn advanced_filter(filter: BooleanFilter) -> Option(Bool) {
  Some(eval_boolean_filter(filter))
}