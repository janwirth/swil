import gleam/dynamic/decode
import gleam/result
import sqlight
import swil/api_help

const soft_delete_item_by_name_and_age_sql = "update \"item\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null returning \"name\", \"age\";"

/// Delete a item by the `ByNameAndAge` identity.
pub fn delete_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_item_by_name_and_age_sql,
      on: conn,
      with: [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(name),
        sqlight.int(age),
      ],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] ->
      Error(not_found_item_name_and_age_error("delete_item_by_name_and_age"))
  }
}

fn not_found_item_name_and_age_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "item" <> " not found: " <> op, -1)
}
