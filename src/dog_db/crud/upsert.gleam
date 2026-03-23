import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import sqlight

import dog_db/resource.{type DogForUpsert, DogWithNameIsNeutered}
import dog_db/structure.{type DogRow, dog_row_decoder}

pub fn upsert_one(
  conn: sqlight.Connection,
  dog: DogForUpsert,
) -> Result(DogRow, sqlight.Error) {
  let stamp = 1
  case dog {
    DogWithNameIsNeutered(name: name, age:, is_neutered: is_neutered) -> {
      let upsert =
        "insert into dogs (name, age, is_neutered, created_at, updated_at, deleted_at) values (?, ?, ?, ?, ?, null) on conflict(name, is_neutered) do update set age = excluded.age, updated_at = excluded.updated_at, deleted_at = null"
      use _ <- result.try(sqlight.query(
        upsert,
        on: conn,
        with: [
          sqlight.nullable(sqlight.text, option.Some(name)),
          sqlight.nullable(sqlight.int, age),
          sqlight.nullable(sqlight.int, option.Some(case is_neutered { True -> 1 False -> 0 })),
          sqlight.int(stamp),
          sqlight.int(stamp),
        ],
        expecting: decode.success(Nil),
      ))
      sqlight.query(
        "select id, created_at, updated_at, deleted_at, name, age, is_neutered from dogs where name = ? and is_neutered = ? and deleted_at is null limit 1",
        on: conn,
        with: [
          sqlight.text(name),
          sqlight.int(case is_neutered { True -> 1 False -> 0 }),
        ],
        expecting: dog_row_decoder(),
      )
      |> result.map(fn(rows) {
        let assert [r] = rows
        r
      })
    }
  }
}

pub fn upsert_many(
  conn: sqlight.Connection,
  rows: List(DogForUpsert),
) -> Result(List(DogRow), sqlight.Error) {
  list.try_map(over: rows, with: fn(c) { upsert_one(conn, c) })
}
