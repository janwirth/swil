import api_help
import dsl/dsl as dsl
import case_studies/fruit_schema.{type Fruit, ByName, Fruit}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}

pub fn fruit_with_magic_row_decoder() -> decode.Decoder(#(Fruit, dsl.MagicFields)) {
  use name <- decode.field(0, decode.string)
  use color <- decode.field(1, decode.string)
  use price <- decode.field(2, decode.float)
  use quantity <- decode.field(3, decode.int)
  use id <- decode.field(4, decode.int)
  use created_at <- decode.field(5, decode.int)
  use updated_at <- decode.field(6, decode.int)
  use deleted_at_raw <- decode.field(7, decode.optional(decode.int))
  let fruit =
    Fruit(
      name: Some(name),
      color: api_help.opt_string_from_db(color),
      price: Some(price),
      quantity: Some(quantity),
      identities: ByName(name:),
    )
  decode.success(#(
    fruit,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
