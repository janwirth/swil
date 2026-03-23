import gleam/list
import gleam/string

import generator/schema_context.{type SchemaContext}
import generator/sql_types

pub fn generate(ctx: SchemaContext) -> String {
  let t = ctx.type_name
  let v = ctx.variant_name
  let upsert = ctx.for_upsert_type_name
  let uv = ctx.for_upsert_variant_name
  let singular = ctx.singular
  let primary = case ctx.identity_labels {
    [l, ..] -> l
    [] -> ""
  }
  let resource_fields =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      label <> ": " <> sql_types.rendered_type(typ)
    })
    |> string.join(", ")
  let upsert_params =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      let typ_out = case label == primary {
        True -> "String"
        False -> sql_types.rendered_type(typ)
      }
      label <> ": " <> typ_out
    })
    |> string.join(", ")
  "import gleam/option.{type Option}\n"
  <> "\n"
  <> "pub type "
  <> t
  <> " {\n"
  <> "  "
  <> v
  <> "("
  <> resource_fields
  <> ")\n"
  <> "}\n"
  <> "\n"
  <> "pub type "
  <> upsert
  <> " {\n"
  <> "  "
  <> uv
  <> "("
  <> upsert_params
  <> ")\n"
  <> "}\n"
  <> "\n"
  <> "pub fn "
  <> singular
  <> "_with_"
  <> primary
  <> "("
  <> upsert_params
  <> ") -> "
  <> upsert
  <> " {\n"
  <> "  "
  <> uv
  <> "("
  <> join_field_labels(ctx.fields)
  <> ")\n"
  <> "}\n"
}

fn join_field_labels(fields: List(#(String, a))) -> String {
  case fields {
    [] -> ""
    [#(l, _), ..rest] ->
      l
      <> ":"
      <> case rest {
        [] -> ""
        _ -> ", " <> join_field_labels(rest)
      }
  }
}
