import gleam/dynamic/decode
import gleam/list
import gleam/result
import sqlight

import cats_schema_generated/resource.{type CatForUpsert, CatWithName}
import cats_schema_generated/structure.{type CatRow, cat_row_decoder}

pub fn upsert_one(
  conn: sqlight.Connection,
  cat: CatForUpsert,
) -> Result(CatRow, sqlight.Error) {
  let stamp = 1
  case cat {
    CatWithName(name: name_str, age:) -> {
      let upsert =
        "insert into cats (name, age, created_at, updated_at, deleted_at) values (?, ?, ?, ?, null) on conflict(name) do update set age = excluded.age, updated_at = excluded.updated_at, deleted_at = null"
      use _ <- result.try(sqlight.query(
        upsert,
        on: conn,
        with: [
          sqlight.text(name_str),
          sqlight.nullable(sqlight.int, age),
          sqlight.int(stamp),
          sqlight.int(stamp),
        ],
        expecting: decode.success(Nil),
      ))
      sqlight.query(
        "select id, created_at, updated_at, deleted_at, name, age from cats where name = ? and deleted_at is null limit 1",
        on: conn,
        with: [sqlight.text(name_str)],
        expecting: cat_row_decoder(),
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
  rows: List(CatForUpsert),
) -> Result(List(CatRow), sqlight.Error) {
  list.try_map(over: rows, with: fn(c) { upsert_one(conn, c) })
}
