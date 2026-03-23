import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some, map}
import gleam/result
import sqlight

import cat_db/structure.{type CatRow, cat_row_decoder}
import cat_schema.{type Cat}

pub fn update_one(
  conn: sqlight.Connection,
  id: Int,
  cat: cat_schema.Cat,
) -> Result(Option(CatRow), sqlight.Error) {
  use _ <- result.try(sqlight.query(
    "update cats set name = ?, age = ?, updated_at = ? where id = ? and deleted_at is null",
    on: conn,
    with: [
      sqlight.nullable(sqlight.text, cat.name),
      sqlight.nullable(sqlight.int, cat.age),
      sqlight.int(1),
      sqlight.int(id),
    ],
    expecting: decode.success(Nil),
  ))
  use rows <- result.try(sqlight.query(
    "select id, created_at, updated_at, deleted_at, name, age from cats where id = ? and deleted_at is null limit 1",
    on: conn,
    with: [sqlight.int(id)],
    expecting: cat_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(Some(row))
    [] -> Ok(None)
  }
}

pub fn update_many(
  conn: sqlight.Connection,
  rows: List(#(Int, Cat)),
) -> Result(List(Option(CatRow)), sqlight.Error) {
  list.try_map(over: rows, with: fn(row) {
    let #(id, cat) = row
    update_one(conn, id, cat)
  })
}
