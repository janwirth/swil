import cake/delete as cake_delete
import cake/where
import gleam/dynamic/decode
import gleam/list
import gleam/result
import help/cake_sql_exec
import sqlight

pub fn delete_one(conn: sqlight.Connection, id: Int) -> Result(
  Nil,
  sqlight.Error,
) {
  use _ <- result.try({
      let q = cake_delete.to_query(
        cake_delete.where(
          cake_delete.table(cake_delete.new(), "cats"),
          where.eq(where.col("id"), where.int(id)),
        ),
      )
      cake_sql_exec.run_write_query(q, decode.success(Nil), conn)
    })
  Ok(Nil)
}

pub fn delete_many(conn: sqlight.Connection, ids: List(Int)) -> Result(
  Nil,
  sqlight.Error,
) {
  case list.is_empty(ids) {
    True -> Ok(Nil)
    False -> result.try(
      let q
      =
      cake_delete.to_query(
        cake_delete.where(
          cake_delete.table(cake_delete.new(), "cats"),
          where.in(where.col("id"), list.map(ids, where.int)),
        ),
      )
      cake_sql_exec.run_write_query(q, decode.success(Nil), conn),
      fn(_)
      ->
      Result(Nil, sqlight.Error)
      { Ok(Nil) },
    )
  }
}