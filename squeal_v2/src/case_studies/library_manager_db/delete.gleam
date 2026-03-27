import api_help
import gleam/dynamic/decode
import gleam/result
import sqlight

const soft_delete_by_title_and_artist_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null returning \"title\", \"artist\";"

/// Delete a importedtrack by the `ByTitleAndArtist` identity.
pub fn delete_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_by_title_and_artist_sql,
      on: conn,
      with: [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(title),
        sqlight.text(artist),
      ],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_error("delete_importedtrack_by_title_and_artist"))
  }
}

fn not_found_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack"
    <>
    " not found: "
    <>
    op,
    -1,
  )
}
