import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import sqlight

import cats_schema_generated/resource.{type Cat}
import cats_schema_generated/structure.{type CatRow, cat_row_decoder}

fn has_identity(cat: Cat) -> Bool {
  case cat.name {
    Some(_) -> True
    None -> False
  }
}

fn missing_identity_error(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  case sqlight.query(
    "this is not valid sql -- at least one identity field must be provided for upsert",
    on: conn,
    with: [],
    expecting: decode.success(Nil),
  ) {
    Error(err) -> Error(err)
    Ok(_) -> Ok(Nil)
  }
}

pub fn upsert_one(conn: sqlight.Connection, cat: Cat) -> Result(CatRow, sqlight.Error) {
  use _ <- result.try(case has_identity(cat) {
    True -> Ok(Nil)
    False -> missing_identity_error(conn)
  })
  let stamp = 1
  case cat.name {
    Some(name_str) -> {
      let upsert =
        "insert into cats (name, age, created_at, updated_at, deleted_at) values (?, ?, ?, ?, null) on conflict(name) do update set age = excluded.age, updated_at = excluded.updated_at, deleted_at = null"
      use _ <- result.try(sqlight.query(
        upsert,
        on: conn,
        with: [
          sqlight.text(name_str),
          sqlight.nullable(sqlight.int, cat.age),
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
    None -> {
      use _ <- result.try(missing_identity_error(conn))
      sqlight.query(
        "select id, created_at, updated_at, deleted_at, name, age from cats where id = -1",
        on: conn,
        with: [],
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
  rows: List(Cat),
) -> Result(List(CatRow), sqlight.Error) {
  list.try_map(over: rows, with: fn(c) { upsert_one(conn, c) })
}
