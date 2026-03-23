import gleam/list
import gleam/option.{type Option, None, Some}
import sqlight

import cat_db/structure.{
  type CatField, type FilterableCat, type NumRefOrValue, type StringRefOrValue,
  AgeInt, CreatedAtInt, DeletedAtInt, FilterableCat, IdInt, NameString, NumRef,
  NumValue, StringRef, StringValue, UpdatedAtInt,
}
import help/filter

pub type Filter =
  fn(FilterableCat) -> filter.BoolExpr(NumRefOrValue, StringRefOrValue)

pub fn filter_arg(
  nullable_filter: Option(Filter),
  sort: Option(filter.SortOrder(CatField)),
) -> filter.FilterArg(FilterableCat, NumRefOrValue, StringRefOrValue, CatField) {
  case nullable_filter {
    Some(f) -> filter.FilterArg(filter: f, sort: sort)
    None -> filter.NoFilter(sort: sort)
  }
}

pub fn filterable_refs() -> FilterableCat {
  FilterableCat(
    name: StringRef(NameString),
    age: NumRef(AgeInt),
    id: NumRef(IdInt),
    created_at: NumRef(CreatedAtInt),
    updated_at: NumRef(UpdatedAtInt),
    deleted_at: NumRef(DeletedAtInt),
  )
}

fn num_operand_sql(op: NumRefOrValue) -> #(String, List(sqlight.Value)) {
  case op {
    NumRef(AgeInt) -> #("age", [])
    NumRef(IdInt) -> #("id", [])
    NumRef(CreatedAtInt) -> #("created_at", [])
    NumRef(UpdatedAtInt) -> #("updated_at", [])
    NumRef(DeletedAtInt) -> #("deleted_at", [])
    NumValue(value: v) -> #("?", [sqlight.int(v)])
  }
}

fn string_operand_sql(op: StringRefOrValue) -> #(String, List(sqlight.Value)) {
  case op {
    StringRef(NameString) -> #("name", [])
    StringValue(value: s) -> #("?", [sqlight.text(s)])
  }
}

pub fn bool_expr_sql(
  expr: filter.BoolExpr(NumRefOrValue, StringRefOrValue),
) -> #(String, List(sqlight.Value)) {
  case expr {
    filter.LiteralTrue -> #("1 = 1", [])
    filter.LiteralFalse -> #("1 = 0", [])
    filter.Not(inner) -> {
      let #(s, p) = bool_expr_sql(inner)
      #("not (" <> s <> ")", p)
    }
    filter.And(left, right) -> {
      let #(ls, lp) = bool_expr_sql(left)
      let #(rs, rp) = bool_expr_sql(right)
      #("(" <> ls <> ") and (" <> rs <> ")", list.append(lp, rp))
    }
    filter.Or(left, right) -> {
      let #(ls, lp) = bool_expr_sql(left)
      let #(rs, rp) = bool_expr_sql(right)
      #("(" <> ls <> ") or (" <> rs <> ")", list.append(lp, rp))
    }
    filter.Gt(left, right) -> {
      let #(ls, lp) = num_operand_sql(left)
      let #(rs, rp) = num_operand_sql(right)
      #(ls <> " > " <> rs, list.append(lp, rp))
    }
    filter.Eq(left, right) -> {
      let #(ls, lp) = num_operand_sql(left)
      let #(rs, rp) = num_operand_sql(right)
      #(ls <> " = " <> rs, list.append(lp, rp))
    }
    filter.Ne(left, right) -> {
      let #(ls, lp) = num_operand_sql(left)
      let #(rs, rp) = num_operand_sql(right)
      #(ls <> " <> " <> rs, list.append(lp, rp))
    }
    filter.NotContains(left, right) -> {
      let #(ls, lp) = string_operand_sql(left)
      let #(rs, rp) = string_operand_sql(right)
      #("instr(" <> ls <> ", " <> rs <> ") = 0", list.append(lp, rp))
    }
  }
}
