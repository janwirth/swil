import gleam/option.{type Option, None, Some}
import gleam/result
import sqlight

import dog_db/crud/filter as crud_filter
import dog_db/crud/sort as crud_sort
import dog_db/structure.{
  type DogField,
  type DogRow,
  type FilterableDog,
  type NumRefOrValue,
  type StringRefOrValue,
  dog_row_decoder,
}
import help/filter

pub fn read_one(conn: sqlight.Connection, id: Int) -> Result(Option(DogRow), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    "select id, created_at, updated_at, deleted_at, name, age, is_neutered from dogs where id = ? and deleted_at is null",
    on: conn,
    with: [sqlight.int(id)],
    expecting: dog_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(Some(row))
    [] -> Ok(None)
  }
}

fn read_many_sql(
  arg: filter.FilterArg(FilterableDog, NumRefOrValue, StringRefOrValue, DogField),
) -> #(String, List(sqlight.Value)) {
  let base =
    "select id, created_at, updated_at, deleted_at, name, age, is_neutered from dogs where deleted_at is null and "
  case arg {
    filter.NoFilter(sort: s) -> #(base <> "1 = 1" <> crud_sort.sort_clause(s), [])
    filter.FilterArg(filter: f, sort: s) -> {
      let #(cond, params) = crud_filter.bool_expr_sql(f(crud_filter.filterable_refs()))
      #(base <> "(" <> cond <> ")" <> crud_sort.sort_clause(s), params)
    }
  }
}

pub fn read_many(
  conn: sqlight.Connection,
  arg: filter.FilterArg(FilterableDog, NumRefOrValue, StringRefOrValue, DogField),
) -> Result(List(DogRow), sqlight.Error) {
  let #(sql, params) = read_many_sql(arg)
  sqlight.query(sql, on: conn, with: params, expecting: dog_row_decoder())
}
