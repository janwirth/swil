import gleam/dynamic/decode
import gleam/result
import sqlight
import swil/api_help

const soft_delete_mytrack_by_name_sql = "update \"mytrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null returning \"name\";"

/// Delete a mytrack by the `ByName` identity.
pub fn delete_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_mytrack_by_name_sql,
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
    [] -> Error(not_found_mytrack_name_error("delete_mytrack_by_name"))
  }
}

fn not_found_mytrack_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "mytrack" <> " not found: " <> op,
    -1,
  )
}
