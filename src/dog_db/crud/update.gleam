import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some, map}
import gleam/result
import sqlight

import dog_db/structure.{type DogRow, dog_row_decoder}
import dog_schema.{type Dog}

pub fn update_one(
  conn: sqlight.Connection,
  id: Int,
  dog: dog_schema.Dog,
) -> Result(Option(DogRow), sqlight.Error) {
  use _ <- result.try(sqlight.query(
    "update dogs set name = ?, age = ?, is_neutered = ?, updated_at = ? where id = ? and deleted_at is null",
    on: conn,
    with: [
      sqlight.nullable(sqlight.text, dog.name),
      sqlight.nullable(sqlight.int, dog.age),
      sqlight.nullable(sqlight.int, map(dog.is_neutered, fn(b) { case b { True -> 1 False -> 0 } })),
      sqlight.int(1),
      sqlight.int(id),
    ],
    expecting: decode.success(Nil),
  ))
  use rows <- result.try(sqlight.query(
    "select id, created_at, updated_at, deleted_at, name, age, is_neutered from dogs where id = ? and deleted_at is null limit 1",
    on: conn,
    with: [sqlight.int(id)],
    expecting: dog_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(Some(row))
    [] -> Ok(None)
  }
}

pub fn update_many(
  conn: sqlight.Connection,
  rows: List(#(Int, Dog)),
) -> Result(List(Option(DogRow)), sqlight.Error) {
  list.try_map(over: rows, with: fn(row) {
    let #(id, dog) = row
    update_one(conn, id, dog)
  })
}
