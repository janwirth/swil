import cake/delete as cake_delete
import cake/where
import gleam/dynamic/decode
import gleam/list
import gleam/result
import sqlight

import help/cake_sql_exec

pub fn delete_one(
  conn: sqlight.Connection,
  id: Int,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try({
    let q =
      cake_delete.new()
      |> cake_delete.table("dogs")
      |> cake_delete.where(where.eq(where.col("id"), where.int(id)))
      |> cake_delete.to_query
    cake_sql_exec.run_write_query(q, decode.success(Nil), conn)
  })
  Ok(Nil)
}

pub fn delete_many(
  conn: sqlight.Connection,
  ids: List(Int),
) -> Result(Nil, sqlight.Error) {
  case ids {
    [] -> Ok(Nil)
    _ -> {
      use _ <- result.try({
        let q =
          cake_delete.new()
          |> cake_delete.table("dogs")
          |> cake_delete.where(where.in(
            where.col("id"),
            list.map(ids, where.int),
          ))
          |> cake_delete.to_query
        cake_sql_exec.run_write_query(q, decode.success(Nil), conn)
      })
      Ok(Nil)
    }
  }
}
