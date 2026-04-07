pub type FruitRow {
  FruitRow(
    name: option.Option(String),
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
}

import case_studies/fruit_schema
import gleam/dynamic/decode
import gleam/option
import swil/dsl
import swil/runtime/api_help

pub fn fruit_with_magic_row_decoder() -> decode.Decoder(
  #(FruitRow, dsl.MagicFields),
) {
  use name <- decode.field(0, decode.string)
  use color <- decode.field(1, decode.optional(decode.string))
  use price <- decode.field(2, decode.optional(decode.float))
  use quantity <- decode.field(3, decode.optional(decode.int))
  use id <- decode.field(4, decode.int)
  use created_at <- decode.field(5, decode.int)
  use updated_at <- decode.field(6, decode.int)
  use deleted_at_raw <- decode.field(7, decode.optional(decode.int))
  let fruit_row =
    FruitRow(
      name: option.Some(name),
      color: api_help.option_string_from_optional_db(color),
      price: price,
      quantity: quantity,
    )
  decode.success(#(
    fruit_row,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
