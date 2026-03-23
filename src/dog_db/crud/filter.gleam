import cake/fragment.{
  literal as frag_literal, placeholder as frag_ph, prepared as frag_prepared,
  string as frag_string,
}
import cake/where
import gleam/option.{type Option, None, Some}

import dog_db/structure.{
  type DogField, type FilterableDog, type NumRefOrValue, type StringRefOrValue,
  AgeInt, CreatedAtInt, DeletedAtInt, FilterableDog, IdInt, IsNeuteredInt,
  NameString, NumRef, NumValue, StringRef, StringValue, UpdatedAtInt,
}
import help/filter

pub type Filter =
  fn(FilterableDog) -> filter.BoolExpr(NumRefOrValue, StringRefOrValue)

pub fn filter_arg(
  nullable_filter: Option(Filter),
  sort: Option(filter.SortOrder(DogField)),
) -> filter.FilterArg(FilterableDog, NumRefOrValue, StringRefOrValue, DogField) {
  case nullable_filter {
    Some(f) -> filter.FilterArg(filter: f, sort: sort)
    None -> filter.NoFilter(sort: sort)
  }
}

pub fn filterable_refs() -> FilterableDog {
  FilterableDog(
    name: StringRef(NameString),
    age: NumRef(AgeInt),
    is_neutered: NumRef(IsNeuteredInt),
    id: NumRef(IdInt),
    created_at: NumRef(CreatedAtInt),
    updated_at: NumRef(UpdatedAtInt),
    deleted_at: NumRef(DeletedAtInt),
  )
}

fn num_operand_where_value(op: NumRefOrValue) -> where.WhereValue {
  case op {
    NumRef(AgeInt) -> where.col("age")
    NumRef(IsNeuteredInt) -> where.col("is_neutered")
    NumRef(IdInt) -> where.col("id")
    NumRef(CreatedAtInt) -> where.col("created_at")
    NumRef(UpdatedAtInt) -> where.col("updated_at")
    NumRef(DeletedAtInt) -> where.col("deleted_at")
    NumValue(value: v) -> where.int(v)
  }
}

fn string_operand_part(op: StringRefOrValue) -> #(Bool, String) {
  case op {
    StringRef(NameString) -> #(True, "name")
    StringValue(value: s) -> #(False, s)
  }
}

fn instr_where(left: #(Bool, String), right: #(Bool, String)) -> where.Where {
  case left, right {
  #(True, lc), #(True, rc) -> where.fragment(
    frag_literal("instr(" <> lc <> ", " <> rc <> ") = 0"),
  )
  #(True, lc), #(False, rv) -> where.fragment(
    frag_prepared(
      "instr("
      <>
      lc
      <>
      ", "
      <>
      frag_ph
      <>
      ") = 0",
      [frag_string(rv)],
    ),
  )
  #(False, lv), #(True, rc) -> where.fragment(
    frag_prepared(
      "instr("
      <>
      frag_ph
      <>
      ", "
      <>
      rc
      <>
      ") = 0",
      [frag_string(lv)],
    ),
  )
  #(False, lv), #(False, rv) -> where.fragment(
    frag_prepared(
      "instr("
      <>
      frag_ph
      <>
      ", "
      <>
      frag_ph
      <>
      ") = 0",
      [frag_string(lv), frag_string(rv)],
    ),
  )
}
}

pub fn bool_expr_where(
  expr: filter.BoolExpr(NumRefOrValue, StringRefOrValue),
) -> where.Where {
  case expr {
    filter.LiteralTrue -> where.eq(where.int(1), where.int(1))
    filter.LiteralFalse -> where.eq(where.int(1), where.int(0))
    filter.Not(inner) -> where.not(bool_expr_where(inner))
    filter.And(left, right) ->
      where.and([bool_expr_where(left), bool_expr_where(right)])
    filter.Or(left, right) ->
      where.or([bool_expr_where(left), bool_expr_where(right)])
    filter.Gt(left, right) ->
      where.gt(num_operand_where_value(left), num_operand_where_value(right))
    filter.Eq(left, right) ->
      where.eq(num_operand_where_value(left), num_operand_where_value(right))
    filter.Ne(left, right) ->
      where.not(
  where.eq(num_operand_where_value(left), num_operand_where_value(right)),
)
    filter.NotContains(left, right) ->
      instr_where(string_operand_part(left), string_operand_part(right))
  }
}
