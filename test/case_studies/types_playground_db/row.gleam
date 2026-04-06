import case_studies/types_playground_schema
import gleam/dynamic/decode
import gleam/option
import swil/dsl
import swil/runtime/api_help

pub fn mytrack_with_magic_row_decoder() -> decode.Decoder(
  #(types_playground_schema.MyTrack, dsl.MagicFields),
) {
  use added_to_playlist_at <- decode.field(0, decode.optional(decode.int))
  use name <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let mytrack =
    types_playground_schema.MyTrack(
      added_to_playlist_at: api_help.option_timestamp_from_optional_unix(
        added_to_playlist_at,
      ),
      name: option.Some(name),
      identities: types_playground_schema.ByName(name:),
    )
  decode.success(#(
    mytrack,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
