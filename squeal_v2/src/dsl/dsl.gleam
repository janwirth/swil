/// This file contains functions that help consumers describe their schemas
/// and queries
/// NO actual implementation here, just a DSL for describing queries
import gleam/list
import gleam/option.{type Option}
import gleam/time/calendar.{type Date}
import gleam/time/timestamp.{type Timestamp}

// these functions implementations are expanded into individual queries when done
// idempotent migrations may work

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

pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
  todo
}

pub fn nullable(some_val: option.Option(some_type)) -> some_type {
  todo
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

/// SQLite `WHERE` fragment using `?` placeholders; bind `int_params` in order (left-to-right).
pub type SqlFilter {
  SqlFilter(where_sql: String, int_params: List(Int))
}

pub type BooleanFilter(a) {
  And(exprs: List(BooleanFilter(a)))
  Or(exprs: List(BooleanFilter(a)))
  Not(expr: BooleanFilter(a))
  /// OneToMany association leaf: `assoc` is ignored for SQL (EXISTS uses join table only); kept for optional in-memory eval.
  OneToManyAssocHas(assoc: List(a), related_item: Int)
  OneToManyAssocNotHas(assoc: List(a), related_item: Int)
  OneToManyAssocCompare(assoc: List(a), related_item: Int, pred: WithPredicate)
}

pub type RecursiveFilterSpec(payload) {
  RecursiveAnd(items: List(RecursiveFilterSpec(payload)))
  RecursiveOr(items: List(RecursiveFilterSpec(payload)))
  RecursiveNot(item: RecursiveFilterSpec(payload))
  RecursivePredicate(item: payload)
}

pub fn has(field: List(a), related_item: Int) -> BooleanFilter(a) {
  OneToManyAssocHas(field, related_item)
}

pub fn not_has(field: List(a), related_item: Int) -> BooleanFilter(a) {
  OneToManyAssocNotHas(field, related_item)
}

pub fn has_with(
  field: List(BelongsTo(related, attribs)),
  related_id: Int,
  predicate: WithPredicate,
  select: fn(related,attribs) -> a
) -> BooleanFilter(BelongsTo(related, attribs))  {
  OneToManyAssocCompare(field, related_id, predicate)
}

pub fn any(
  relationship: List(BelongsTo(related, attribs)),
  select: fn(related, MagicFields, attribs) -> Bool,
) -> BooleanFilter(BelongsTo(related, attribs)) {
  panic as "this is DSL"
}

pub fn complex_filter(
  root: root,
  filter: RecursiveFilterSpec(t),
  predicate_fn predicate_fn: fn(root, t) -> BooleanFilter(a),
) -> BooleanFilter(a) {
  case filter {
    RecursiveAnd(items: items) ->
      And(
        exprs: list.map(items, fn(item) {
          complex_filter(root, item, predicate_fn)
        }),
      )
    RecursiveOr(items: items) ->
      Or(
        exprs: list.map(items, fn(item) {
          complex_filter(root, item, predicate_fn)
        }),
      )
    RecursiveNot(item: item) ->
      Not(expr: complex_filter(root, item, predicate_fn))
    RecursivePredicate(item: item) -> predicate_fn(root, item)
  }
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

/// Naming for `EXISTS (select 1 from join_table j where j.fk = alias.pk and …)`.
pub type OneToManyJoinSqlNaming {
  OneToManyJoinSqlNaming(
    join_table: String,
    parent_alias: String,
    parent_pk_column: String,
    fk_column: String,
    related_item_column: String,
    weight_column: String,
  )
}

fn pred_satisfied(weight: Int, pred: WithPredicate) -> Bool {
  case pred {
    AtLeast(n) -> weight >= n
    AtMost(n) -> weight <= n
    EqualTo(n) -> weight == n
  }
}
pub type BelongsTo(a, attributes) {
  BelongsTo(item: a)
  BelongsToWith(item: a, attributes: Option(attributes))
}


pub type Backlink(kind) {
  Backlink(items: List(kind))
}

pub type BacklinkWith(kind, attributes) {
  BacklinkWith(items: List(kind), attributes: Option(attributes))
}

pub type Query(t) {
  Query(root: t)
}

pub fn query(t: t) -> Query(t) {
  Query(root: t)
}

pub fn shape(q: Query(t), _shape: some) -> Query(t) {
  q
}

pub fn order(q: Query(t), _order: #(some, Direction)) -> Query(t) {
  q
}

pub fn filter_bool(q:Query(t), expr: Bool) -> Query(t) {
  panic as "this is DSL - should never be called"
}

pub fn filter_complex(q:Query(t), filter: RecursiveFilterSpec(f), predicate_fn: fn(t, f) -> BooleanFilter(a)) -> Query(t) {
  panic as "this is DSL - should never be called"
}