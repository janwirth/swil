import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import sqlight

pub fn delete_one(conn: sqlight.Connection, id: Int) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlight.query(
    "delete from dogs where id = ?",
    on: conn,
    with: [sqlight.int(id)],
    expecting: decode.success(Nil),
  ))
  Ok(Nil)
}

pub fn delete_many(conn: sqlight.Connection, ids: List(Int)) -> Result(Nil, sqlight.Error) {
  case ids {
    [] -> Ok(Nil)
    _ -> {
      let placeholders = list.map(ids, fn(_) { "?" }) |> string.join(", ")
      let sql = "delete from dogs where id in (" <> placeholders <> ")"
      let args = list.map(ids, sqlight.int)
      use _ <- result.try(sqlight.query(
        sql,
        on: conn,
        with: args,
        expecting: decode.success(Nil),
      ))
      Ok(Nil)
    }
  }
}
