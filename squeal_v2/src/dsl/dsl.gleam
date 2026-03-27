/// This file contains functions that help consumers describe their schemas
/// and queries
import gleam/list
import gleam/option.{type Option, Some}
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

// composing queries
pub type Query(type_, shape, order_field) {
  Query(
    shape: shape,
    filter: Option(CompiledFilter),
    order: #(order_field, Direction),
  )
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

/// Carries either a boolean predicate (resolved per-row in codegen) or a pre-built SQL clause with bind parameters.
pub type CompiledFilter {
  Predicate(value: Bool)
  SqlWhere(filter: SqlFilter)
}

/// SQLite `WHERE` fragment using `?` placeholders; bind `int_params` in order (left-to-right).
pub type SqlFilter {
  SqlFilter(where_sql: String, int_params: List(Int))
}

pub type BooleanFilter {
  And(exprs: List(BooleanFilter))
  Or(exprs: List(BooleanFilter))
  Not(expr: BooleanFilter)
  /// Tag association leaf: `assoc` is ignored for SQL (EXISTS uses join table only); kept for optional in-memory eval.
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

fn pred_sql_op(pred: WithPredicate) -> #(String, Int) {
  case pred {
    AtLeast(n) -> #(">=", n)
    AtMost(n) -> #("<=", n)
    EqualTo(n) -> #("=", n)
  }
}

/// Naming for `EXISTS (select 1 from join_table j where j.fk = alias.pk and …)`.
pub type TagJoinSqlNaming {
  TagJoinSqlNaming(
    join_table: String,
    parent_alias: String,
    parent_pk_column: String,
    fk_column: String,
    tag_id_column: String,
    weight_column: String,
  )
}

/// Supported leaves: `And`, `Or`, `Not`, `TagAssoc*`. `assoc` lists are ignored for SQL.
pub fn boolean_filter_tag_join_sql(
  filter: BooleanFilter,
  naming: TagJoinSqlNaming,
) -> SqlFilter {
  let TagJoinSqlNaming(
    join_table:,
    parent_alias:,
    parent_pk_column:,
    fk_column:,
    tag_id_column:,
    weight_column:,
  ) = naming
  let j = "j"
  let exists_base =
    "exists (select 1 from "
    <> join_table
    <> " "
    <> j
    <> " where "
    <> j
    <> "."
    <> fk_column
    <> " = "
    <> parent_alias
    <> "."
    <> parent_pk_column
    <> " and "
    <> j
    <> "."
    <> tag_id_column
    <> " = ?"
  case filter {
    And(exprs) ->
      case exprs {
        [] -> SqlFilter(where_sql: "1", int_params: [])
        _ -> {
          let #(parts, params) =
            list.fold(exprs, #([], []), fn(acc, sub) {
              let #(pp, ps) = acc
              let SqlFilter(where_sql: w, int_params: ip) =
                boolean_filter_tag_join_sql(sub, naming)
              #([w, ..pp], list.append(ps, ip))
            })
          let body =
            list.reverse(parts)
            |> list.intersperse(" and ")
            |> list.fold("", fn(a, s) { a <> s })
          SqlFilter(where_sql: "(" <> body <> ")", int_params: params)
        }
      }
    Or(exprs) ->
      case exprs {
        [] -> SqlFilter(where_sql: "0", int_params: [])
        _ -> {
          let #(parts, params) =
            list.fold(exprs, #([], []), fn(acc, sub) {
              let #(pp, ps) = acc
              let SqlFilter(where_sql: w, int_params: ip) =
                boolean_filter_tag_join_sql(sub, naming)
              #([w, ..pp], list.append(ps, ip))
            })
          let body =
            list.reverse(parts)
            |> list.intersperse(" or ")
            |> list.fold("", fn(a, s) { a <> s })
          SqlFilter(where_sql: "(" <> body <> ")", int_params: params)
        }
      }
    Not(expr) -> {
      let SqlFilter(where_sql: w, int_params: p) =
        boolean_filter_tag_join_sql(expr, naming)
      SqlFilter(where_sql: "not (" <> w <> ")", int_params: p)
    }
    TagAssocHas(_assoc, tag_id) ->
      SqlFilter(where_sql: exists_base <> ")", int_params: [tag_id])
    TagAssocNotHas(_assoc, tag_id) ->
      SqlFilter(
        where_sql: "not (" <> exists_base <> "))",
        int_params: [tag_id],
      )
    TagAssocCompare(_assoc, tag_id, pred) -> {
      let #(op, n) = pred_sql_op(pred)
      let clause =
        exists_base
        <> " and "
        <> j
        <> "."
        <> weight_column
        <> " "
        <> op
        <> " ?)"
      SqlFilter(where_sql: clause, int_params: [tag_id, n])
    }
  }
}

fn pred_satisfied(weight: Int, pred: WithPredicate) -> Bool {
  case pred {
    AtLeast(n) -> weight >= n
    AtMost(n) -> weight <= n
    EqualTo(n) -> weight == n
  }
}

/// In-memory evaluation for tests; not used by SQL paths.
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
