/// Functions and types for describing schemas and queries. No runtime query execution here:
/// bodies are placeholders expanded at SQL generation time.
import gleam/option.{type Option}
import gleam/time/calendar.{type Date}
import gleam/time/timestamp.{type Timestamp}

// =============================================================================
// Row metadata
// =============================================================================

pub type MagicFields {
  MagicFields(
    id: Int,
    created_at: Timestamp,
    updated_at: Timestamp,
    deleted_at: Option(Timestamp),
  )
}

// =============================================================================
// Relationship shapes
// =============================================================================

pub type Mutual(a, attributes) {
  Mutual(item: a)
  // maps to same field
}

pub type BelongsTo(a, attributes) {
  BelongsTo(item: a)
  BelongsToWith(item: a, attributes: Option(attributes))
}

// automatically
pub type BacklinkWith(kind, attributes) {
  BacklinkWith(items: List(kind), attributes: Option(attributes))
}

// =============================================================================
// SQL-level expression helpers (stubs; expanded when generating SQL)
// =============================================================================

pub fn age(_t: Date) -> Int {
  panic as "DSL: age is expanded at SQL generation time, not implemented here"
}

pub fn exclude_if_missing(_some_val: option.Option(some_type)) -> some_type {
  panic as "DSL: exclude_if_missing is expanded at SQL generation time, not implemented here"
}

pub fn nullable(_some_val: option.Option(some_type)) -> some_type {
  panic as "DSL: nullable is expanded at SQL generation time, not implemented here"
}

// =============================================================================
// Filter AST (predicates and recursive specs)
// =============================================================================

/// Recursive filter tree: `And` / `Or` / `Not` plus `Predicate` leaves tagged with `a`.
/// - Query parameters: `BooleanFilter(MyLeaf)` (e.g. tag filter built from `Predicate(TagParamExpressionScalar)`; see FILTER_SPEC.md).
/// - `predicate_*` helpers: typically `BooleanFilter(BelongsTo(...))` from `any(...)`, expanded at SQL gen.
pub type BooleanFilter(a) {
  And(exprs: List(BooleanFilter(a)))
  Or(exprs: List(BooleanFilter(a)))
  Not(expr: BooleanFilter(a))
  Predicate(item: a)
}

/// Checks whether any related item (via a junction edge) satisfies the predicate.
///
/// Parameters passed to `select`:
/// 1. `related` — the target entity value (often `_` when only fields matter)
/// 2. `target_magic_fields` — `MagicFields` of the **target** (related) row
/// 3. `edge_attribs` — domain attributes on the **junction** (edge) row
/// 4. `edge_magic_fields` — `MagicFields` of the junction row itself
///
/// Stub: expanded at SQL generation time, never called at runtime.
pub fn any(
  relationship: List(BelongsTo(related, attribs)),
  select: fn(related, MagicFields, attribs, MagicFields) -> Bool,
) -> BooleanFilter(BelongsTo(related, attribs)) {
  let _ = relationship
  let _ = select
  panic as "DSL: any is expanded at SQL generation time, not implemented here"
}

// =============================================================================
// Query pipeline (phantom-typed: query → shape → filter? → order_by → limit? → offset?)
// =============================================================================

/// Slot markers: duplicate steps are rejected at compile time via incompatible type parameters.
pub type QueryShapeNotSet

pub type QueryShapeSet(projection)

pub type QueryFilterNotSet

pub type QueryFilterSet

pub type QueryOrderNotSet

pub type QueryOrderSet(field, direction)

pub type QueryLimitNotSet

pub type QueryLimitSet

pub type QueryOffsetNotSet

pub type QueryOffsetSet

pub type Direction {
  Asc
  Desc
}

pub type Query(root, shape, filter, order, limit, offset) {
  Query(root: root)
}

pub fn query(
  t: t,
) -> Query(
  t,
  QueryShapeNotSet,
  QueryFilterNotSet,
  QueryOrderNotSet,
  QueryLimitNotSet,
  QueryOffsetNotSet,
) {
  Query(root: t)
}

pub fn shape(
  q: Query(
    root,
    QueryShapeNotSet,
    QueryFilterNotSet,
    QueryOrderNotSet,
    limit_slot,
    offset_slot,
  ),
  _shape: projection,
) -> Query(
  root,
  QueryShapeSet(projection),
  QueryFilterNotSet,
  QueryOrderNotSet,
  limit_slot,
  offset_slot,
) {
  let Query(root: r) = q
  Query(root: r)
}

pub fn order_by(
  q: Query(
    root,
    QueryShapeSet(projection),
    filter_slot,
    QueryOrderNotSet,
    limit_slot,
    offset_slot,
  ),
  _field: field,
  _direction: Direction,
) -> Query(
  root,
  QueryShapeSet(projection),
  filter_slot,
  QueryOrderSet(field, Direction),
  limit_slot,
  offset_slot,
) {
  let Query(root: r) = q
  Query(root: r)
}

pub fn limit(
  q: Query(
    root,
    shape_slot,
    filter_slot,
    order_slot,
    QueryLimitNotSet,
    QueryOffsetNotSet,
  ),
  limit limit: Int,
) -> Query(root, shape_slot, filter_slot, order_slot, QueryLimitSet, QueryOffsetNotSet) {
  let _ = limit
  let Query(root: r) = q
  Query(root: r)
}

pub fn offset(
  q: Query(
    root,
    shape_slot,
    filter_slot,
    order_slot,
    QueryLimitSet,
    QueryOffsetNotSet,
  ),
  offset offset: Int,
) -> Query(root, shape_slot, filter_slot, order_slot, QueryLimitSet, QueryOffsetSet) {
  let _ = offset
  let Query(root: r) = q
  Query(root: r)
}

pub fn filter_bool(
  q: Query(
    root,
    QueryShapeSet(projection),
    QueryFilterNotSet,
    QueryOrderNotSet,
    limit_slot,
    offset_slot,
  ),
  _expr: Bool,
) -> Query(
  root,
  QueryShapeSet(projection),
  QueryFilterSet,
  QueryOrderNotSet,
  limit_slot,
  offset_slot,
) {
  let Query(root: _) = q
  panic as "this is DSL - should never be called"
}

pub fn filter_complex(
  q: Query(
    root,
    QueryShapeSet(projection),
    QueryFilterNotSet,
    QueryOrderNotSet,
    limit_slot,
    offset_slot,
  ),
  _filter: BooleanFilter(f),
  _predicate_fn: fn(t, f) -> BooleanFilter(a),
) -> Query(
  root,
  QueryShapeSet(projection),
  QueryFilterSet,
  QueryOrderNotSet,
  limit_slot,
  offset_slot,
) {
  let Query(root: _) = q
  panic as "this is DSL - should never be called"
}
