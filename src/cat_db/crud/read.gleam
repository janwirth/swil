import cake/select
import cake/where
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import sqlight

import cat_db/crud/filter as crud_filter
import cat_db/crud/sort as crud_sort
import cat_db/structure.{
  type CatField, type CatRow, type FilterableCat, type NumRefOrValue,
  type StringRefOrValue, cat_row_decoder,
}
import help/cake_sql_exec
import help/filter

pub fn read_one(
  conn: sqlight.Connection,
  id: Int,
) -> Result(Option(CatRow), sqlight.Error) {
  use rows <- result.try({
    select.new()
    |> select.from_table("cats")
    |> select.select_col("id")
    |> select.select_col("created_at")
    |> select.select_col("updated_at")
    |> select.select_col("deleted_at")
    |> select.select_col("name")
    |> select.select_col("age")
    |> select.where(
      where.and([
        where.eq(where.col("id"), where.int(id)),
        where.is_null(where.col("deleted_at")),
      ]),
    )
    |> select.to_query
    |> cake_sql_exec.run_read_query(cat_row_decoder(), conn)
  })
  case rows {
    [row, ..] -> Ok(Some(row))
    [] -> Ok(None)
  }
}

fn read_many_sql(
  arg: filter.FilterArg(
    FilterableCat,
    NumRefOrValue,
    StringRefOrValue,
    CatField,
  ),
) -> #(String, List(sqlight.Value)) {
  let base =
    "select id, created_at, updated_at, deleted_at, name, age from cats where deleted_at is null and "
  case arg {
    filter.NoFilter(sort: s) -> #(
      base <> "1 = 1" <> crud_sort.sort_clause(s),
      [],
    )
    filter.FilterArg(filter: f, sort: s) -> {
      let #(cond, params) =
        crud_filter.bool_expr_sql(f(crud_filter.filterable_refs()))
      #(base <> "(" <> cond <> ")" <> crud_sort.sort_clause(s), params)
    }
  }
}

pub fn read_many(
  conn: sqlight.Connection,
  arg: filter.FilterArg(
    FilterableCat,
    NumRefOrValue,
    StringRefOrValue,
    CatField,
  ),
) -> Result(List(CatRow), sqlight.Error) {
  let #(sql, params) = read_many_sql(arg)
  sqlight.query(sql, on: conn, with: params, expecting: cat_row_decoder())
}
