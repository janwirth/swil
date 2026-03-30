import skwil/api_help
import gleam/dynamic/decode
import gleam/result
import sqlight

const soft_delete_fruit_by_name_sql = "update \"fruit\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null returning \"name\";"

/// Delete a fruit by the `ByName` identity.
pub fn delete_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_fruit_by_name_sql,
      on: conn,
      with: [sqlight.int(now), sqlight.int(now), sqlight.text(name)],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_fruit_name_error("delete_fruit_by_name"))
  }
}

fn not_found_fruit_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "fruit" <> " not found: " <> op,
    -1,
  )
}
