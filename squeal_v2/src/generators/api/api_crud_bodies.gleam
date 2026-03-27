import generators/api/api_update_delete as ud
import gleam/list
import gleam/string
import schema_definition/schema_definition.{type IdentityVariantDefinition}

pub fn get_fn_body(
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  decoder_qualifier: String,
  row_qualifier: String,
) -> String {
  let with_part = case list.length(variant.fields) > 1 {
    True -> {
      let lines =
        list.map(variant.fields, fn(f) {
          "      " <> ud.sql_bind_expr(f, f.label, row_qualifier) <> ","
        })
        |> string.join("\n")
      "[\n" <> lines <> "\n    ]"
    }
    False -> {
      let binds =
        list.map(variant.fields, fn(f) {
          ud.sql_bind_expr(f, f.label, row_qualifier)
        })
        |> string.join(", ")
      "[" <> binds <> "]"
    }
  }
  "use rows <- result.try(sqlight.query(\n    select_"
  <> entity_snake
  <> "_by_"
  <> id_snake
  <> "_sql,\n    on: conn,\n    with: "
  <> with_part
  <> ",\n    expecting: "
  <> decoder_qualifier
  <> "."
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  ))\n  case rows {\n    [] -> Ok(None)\n    [r, ..] -> Ok(Some(r))\n  }"
}

pub fn last_fn_body(
  entity_snake: String,
  sql_const_name: String,
  decoder_qualifier: String,
) -> String {
  "sqlight.query(\n    "
  <> sql_const_name
  <> ",\n    on: conn,\n    with: [],\n    expecting: "
  <> decoder_qualifier
  <> "."
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  )"
}
