import cake/update as cake_update
import cake/where
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/time/timestamp
import help/cake_sql_exec
import sqlight

pub fn delete_one(
  conn: sqlight.Connection,
  id: Int,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try({
    let #(now_sec, _) =
      timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
    let q =
      cake_update.to_query(cake_update.where(
        cake_update.set(
          cake_update.set(
            cake_update.table(cake_update.new(), "dogs"),
            cake_update.set_int("deleted_at", now_sec),
          ),
          cake_update.set_int("updated_at", now_sec),
        ),
        where.and([
          where.eq(where.col("id"), where.int(id)),
          where.is_null(where.col("deleted_at")),
        ]),
      ))
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
    ids ->
      result.try(
        {
          let #(now_sec, _) =
            timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
          let q =
            cake_update.to_query(cake_update.where(
              cake_update.set(
                cake_update.set(
                  cake_update.table(cake_update.new(), "dogs"),
                  cake_update.set_int("deleted_at", now_sec),
                ),
                cake_update.set_int("updated_at", now_sec),
              ),
              where.and([
                where.in(where.col("id"), list.map(ids, where.int)),
                where.is_null(where.col("deleted_at")),
              ]),
            ))
          cake_sql_exec.run_write_query(q, decode.success(Nil), conn)
        },
        fn(_) -> Result(Nil, sqlight.Error) { Ok(Nil) },
      )
  }
}
