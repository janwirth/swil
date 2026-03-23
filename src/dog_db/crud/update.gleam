import cake/select
import cake/update as cake_update
import cake/where
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import sqlight

import dog_db/structure.{type DogRow, dog_row_decoder}
import dog_schema.{type Dog}
import help/cake_sql_exec

pub fn update_one(
  conn: sqlight.Connection,
  id: Int,
  dog: dog_schema.Dog,
) -> Result(Option(DogRow), sqlight.Error) {
  use _ <- result.try({
    let #(now_sec, _) =
      timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
    let u = cake_update.table(cake_update.new(), "dogs")
    let u = case dog.name {
      Some(v) -> cake_update.set(u, cake_update.set_string("name", v))
      None -> cake_update.set(u, cake_update.set_null("name"))
    }
    let u = case dog.age {
      Some(v) -> cake_update.set(u, cake_update.set_int("age", v))
      None -> cake_update.set(u, cake_update.set_null("age"))
    }
    let u = case dog.is_neutered {
      Some(v) -> cake_update.set(u, cake_update.set_bool("is_neutered", v))
      None -> cake_update.set(u, cake_update.set_null("is_neutered"))
    }
    let u =
      cake_update.set(u, cake_update.set_int("updated_at", now_sec))
    let q =
      cake_update.to_query(
        cake_update.where(
          u,
          where.and([
            where.eq(where.col("id"), where.int(id)),
            where.is_null(where.col("deleted_at")),
          ]),
        ),
      )
    cake_sql_exec.run_write_query(q, decode.success(Nil), conn)
  })
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

pub fn update_many(
  conn: sqlight.Connection,
  rows: List(#(Int, Dog)),
) -> Result(List(Option(DogRow)), sqlight.Error) {
  list.try_map(over: rows, with: fn(row) {
    let #(id, dog) = row
    update_one(conn, id, dog)
  })
}
