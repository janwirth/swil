import gleam/dynamic/decode
import gleam/result
import sqlight
import swil/api_help

const soft_delete_importedtrack_by_service_and_source_id_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null returning \"service\", \"source_id\";"

/// Delete a importedtrack by the `ByServiceAndSourceId` identity.
pub fn delete_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_importedtrack_by_service_and_source_id_sql,
      on: conn,
      with: [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(service),
        sqlight.text(source_id),
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
      Error(not_found_importedtrack_service_and_source_id_error(
        "delete_importedtrack_by_service_and_source_id",
      ))
  }
}

fn not_found_importedtrack_service_and_source_id_error(
  op: String,
) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}
