import case_studies/additive_item_v2_schema
import gleam/dynamic/decode
import gleam/option
import swil/dsl/dsl
import swil/runtime/api_help

pub fn item_with_magic_row_decoder() -> decode.Decoder(
  #(additive_item_v2_schema.Item, dsl.MagicFields),
) {
  use name <- decode.field(0, decode.string)
  use age <- decode.field(1, decode.optional(decode.int))
  use height <- decode.field(2, decode.optional(decode.float))
  use id <- decode.field(3, decode.int)
  use created_at <- decode.field(4, decode.int)
  use updated_at <- decode.field(5, decode.int)
  use deleted_at_raw <- decode.field(6, decode.optional(decode.int))
  let item =
    additive_item_v2_schema.Item(
      name: option.Some(name),
      age: age,
      height: height,
      identities: additive_item_v2_schema.ByName(name:),
    )
  decode.success(#(
    item,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
