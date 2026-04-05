import gleam/dynamic/decode
import gleam/option
import guide/foundations_01/schema
import swil/dsl/dsl
import swil/runtime/api_help

pub fn guide01item_with_magic_row_decoder() -> decode.Decoder(
  #(schema.Guide01Item, dsl.MagicFields),
) {
  use name <- decode.field(0, decode.string)
  use note <- decode.field(1, decode.optional(decode.string))
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let guide01item =
    schema.Guide01Item(
      name: option.Some(name),
      note: api_help.option_string_from_optional_db(note),
      identities: schema.ByName(name:),
    )
  decode.success(#(
    guide01item,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
