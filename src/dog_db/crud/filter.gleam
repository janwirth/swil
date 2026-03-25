import cake/fragment.{
  literal as frag_literal, placeholder as frag_ph, prepared as frag_prepared,
  string as frag_string,
}
import cake/where
import dog_db/structure.{
  type DogField, type FilterableDog, type NumRefOrValue, type StringRefOrValue,
  AgeInt, CreatedAtInt, DeletedAtInt, FilterableDog, FloatVal, IdInt, IntVal,
  IsNeuteredInt, NameString, NumRef, StrVal, StringRef, UpdatedAtInt,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import help/filter

pub type Filter =
  fn(FilterableDog) -> filter.BoolExpr(NumRefOrValue, StringRefOrValue)

pub fn filter_arg(
  nullable_filter: Option(Filter),
  sort: Option(filter.SortOrder(DogField)),
) -> filter.FilterArg(FilterableDog, NumRefOrValue, StringRefOrValue, DogField) {
  case nullable_filter {
    Some(f) -> filter.FilterArg(f, sort)
    None -> filter.NoFilter(sort)
  }
}

pub fn filterable_refs() -> FilterableDog {
  FilterableDog(
    StringRef(NameString),
    NumRef(AgeInt),
    NumRef(IsNeuteredInt),
    NumRef(IdInt),
    NumRef(CreatedAtInt),
    NumRef(UpdatedAtInt),
    NumRef(DeletedAtInt),
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
    IntVal(v) -> where.int(v)
    FloatVal(v) -> where.float(v)
  }
}

fn string_operand_part(op: StringRefOrValue) -> #(Bool, String) {
  case op {
    StringRef(NameString) -> #(True, "name")
    StrVal(s) -> #(False, s)
  }
}

fn instr_where(
  haystack: #(Bool, String),
  needle: #(Bool, String),
) -> where.Where {
  case haystack, needle {
    #(True, hc), #(True, nc) ->
      where.fragment(frag_literal("instr(" <> hc <> ", " <> nc <> ") = 0"))
    #(True, hc), #(False, nv) ->
      where.fragment(
        frag_prepared("instr(" <> hc <> ", " <> frag_ph <> ") = 0", [
          frag_string(nv),
        ]),
      )
    #(False, hv), #(True, nc) ->
      where.fragment(
        frag_prepared("instr(" <> frag_ph <> ", " <> nc <> ") = 0", [
          frag_string(hv),
        ]),
      )
    #(False, hv), #(False, nv) ->
      where.fragment(
        frag_prepared("instr(" <> frag_ph <> ", " <> frag_ph <> ") = 0", [
          frag_string(hv),
          frag_string(nv),
        ]),
      )
  }
}

pub fn bool_expr_where(
  expr: filter.BoolExpr(NumRefOrValue, StringRefOrValue),
) -> where.Where {
  case expr {
    filter.LiteralTrue -> where.eq(where.int(1), where.int(1))
    filter.LiteralFalse -> where.eq(where.int(1), where.int(0))
    filter.Not(expr) -> where.not(bool_expr_where(expr))
    filter.And(wheres) -> where.and(list.map(wheres, bool_expr_where))
    filter.Or(wheres) -> where.or(list.map(wheres, bool_expr_where))
    filter.Gt(left, right) ->
      where.gt(num_operand_where_value(left), num_operand_where_value(right))
    filter.Eq(left, right) ->
      where.eq(num_operand_where_value(left), num_operand_where_value(right))
    filter.Ne(left, right) ->
      where.not(where.eq(
        num_operand_where_value(left),
        num_operand_where_value(right),
      ))
    filter.NotContains(haystack, needle) ->
      instr_where(string_operand_part(haystack), string_operand_part(needle))
  }
}
