import cake/select
import cake/where
import gleam/option.{type Option, None, Some}
import gleam/result
import sqlight

import dog_db/crud/filter as crud_filter
import dog_db/crud/sort as crud_sort
import dog_db/structure.{
  type DogField, type DogRow, type FilterableDog, type NumRefOrValue,
  type StringRefOrValue, dog_row_decoder,
}
import help/cake_sql_exec
import help/filter

pub fn read_one(
  conn: sqlight.Connection,
  id: Int,
) -> Result(Option(DogRow), sqlight.Error) {
  use rows <- result.try({
    cake_sql_exec.run_read_query(
  select.to_query(
    select.where(
      select.select_cols(
        select.from_table(select.new(), "dogs"),
        [
          "id",
          "created_at",
          "updated_at",
          "deleted_at",
          "name",
          "age",
          "is_neutered",
        ],
      ),
      where.and(
        [
          where.eq(where.col("id"), where.int(id)),
          where.is_null(where.col("deleted_at")),
        ],
      ),
    ),
  ),
  dog_row_decoder(),
  conn,
)
  })
  case rows {
    [row, ..] -> Ok(Some(row))
    [] -> Ok(None)
  }
}

fn read_many_filter_where(
  arg: filter.FilterArg(
    FilterableDog,
    NumRefOrValue,
    StringRefOrValue,
    DogField,
  ),
) -> where.Where {
  case arg {
    filter.NoFilter(..) -> where.eq(where.int(1), where.int(1))
    filter.FilterArg(filter: f, ..) ->
      crud_filter.bool_expr_where(f(crud_filter.filterable_refs()))
  }
}

fn read_many_ordered(
  arg: filter.FilterArg(
    FilterableDog,
    NumRefOrValue,
    StringRefOrValue,
    DogField,
  ),
) {
  let order = case arg {
    filter.NoFilter(sort: s) -> s
    filter.FilterArg(sort: s, ..) -> s
  }
  let base =
    select.where(
  select.select_cols(
    select.from_table(select.new(), "dogs"),
    [
      "id",
      "created_at",
      "updated_at",
      "deleted_at",
      "name",
      "age",
      "is_neutered",
    ],
  ),
  where.and(
    [where.is_null(where.col("deleted_at")), read_many_filter_where(arg)],
  ),
)
  case order {
    None -> base
    Some(filter.Asc(f)) ->
      select.order_by_asc(base, crud_sort.dog_field_sql(f))
    Some(filter.Desc(f)) ->
      select.order_by_desc(base, crud_sort.dog_field_sql(f))
  }
}

pub fn read_many(
  conn: sqlight.Connection,
  arg: filter.FilterArg(
    FilterableDog,
    NumRefOrValue,
    StringRefOrValue,
    DogField,
  ),
) -> Result(List(DogRow), sqlight.Error) {
  read_many_ordered(arg)
  |> select.to_query
  |> cake_sql_exec.run_read_query(dog_row_decoder(), conn)
}
