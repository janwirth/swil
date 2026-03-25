import gleam/option.{type Option}

pub type SortOrder(field) {
  Asc(field)
  Desc(field)
}

pub type FilterArg(t, num_ref, string_ref, sort_field) {
  FilterArg(
    filter: fn(t) -> BoolExpr(num_ref, string_ref),
    sort: Option(SortOrder(sort_field)),
  )
  NoFilter(sort: Option(SortOrder(sort_field)))
}

pub type BoolExpr(num_ref, string_ref) {
  And(wheres: List(BoolExpr(num_ref, string_ref)))
  Or(wheres: List(BoolExpr(num_ref, string_ref)))
  Not(expr: BoolExpr(num_ref, string_ref))

  LiteralTrue
  LiteralFalse

  Gt(left: num_ref, right: num_ref)
  Eq(left: num_ref, right: num_ref)
  Ne(left: num_ref, right: num_ref)

  NotContains(haystack: string_ref, needle: string_ref)
}
