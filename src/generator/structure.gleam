import glance
import gleam/int
import gleam/list
import gleam/string

import generator/schema_context.{type SchemaContext, pascal_case_field_label}
import generator/sql_types

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let t = ctx.type_name
  let v = ctx.variant_name
  let fl = ctx.filterable_name
  let row = ctx.row_name
  let db = ctx.db_type_name
  let fe = ctx.field_enum_name
  let ne = ctx.num_field_enum_name
  let se = ctx.string_field_enum_name
  let upsert = ctx.for_upsert_type_name
  let singular = ctx.singular
  let filterable_body = filterable_record(ctx)
  let num_enum = num_field_enum(ctx)
  let str_enum = string_field_enum(ctx)
  let field_enum = full_field_enum(ctx)
  let decoder_lines = row_decoder_body(ctx)
  let decoder_fn = singular <> "_row_decoder"
  "import gleam/dynamic/decode\n"
  <> "import gleam/option.{type Option}\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/resource.{type "
  <> t
  <> ", type "
  <> upsert
  <> ", "
  <> v
  <> "}\n"
  <> "import help/filter\n"
  <> "import sqlight\n"
  <> "\n"
  <> "pub type "
  <> fl
  <> " {\n"
  <> filterable_body
  <> "}\n"
  <> "\n"
  <> "pub type StringRefOrValue {\n"
  <> "  StringRef(ref: "
  <> se
  <> ")\n"
  <> "  StringValue(value: String)\n"
  <> "}\n"
  <> "\n"
  <> "pub type NumRefOrValue {\n"
  <> "  NumRef(ref: "
  <> ne
  <> ")\n"
  <> "  NumValue(value: Int)\n"
  <> "}\n"
  <> "\n"
  <> "pub type "
  <> ne
  <> " {\n"
  <> num_enum
  <> "}\n"
  <> "\n"
  <> "pub type "
  <> se
  <> " {\n"
  <> str_enum
  <> "}\n"
  <> "\n"
  <> "pub type "
  <> fe
  <> " {\n"
  <> field_enum
  <> "}\n"
  <> "\n"
  <> "pub type "
  <> row
  <> " {\n"
  <> "  "
  <> row
  <> "(\n"
  <> "    value: "
  <> t
  <> ",\n"
  <> "    id: Int,\n"
  <> "    created_at: Int,\n"
  <> "    updated_at: Int,\n"
  <> "    deleted_at: Option(Int),\n"
  <> "  )\n"
  <> "}\n"
  <> "\n"
  <> "pub type "
  <> db
  <> " {\n"
  <> "  "
  <> db
  <> "(\n"
  <> "    migrate: fn() -> Result(Nil, sqlight.Error),\n"
  <> "    upsert_one: fn("
  <> upsert
  <> ") -> Result("
  <> row
  <> ", sqlight.Error),\n"
  <> "    upsert_many: fn(List("
  <> upsert
  <> ")) -> Result(List("
  <> row
  <> "), sqlight.Error),\n"
  <> "    update_one: fn(Int, "
  <> t
  <> ") -> Result(Option("
  <> row
  <> "), sqlight.Error),\n"
  <> "    update_many: fn(List(#(Int, "
  <> t
  <> "))) -> Result(List(Option("
  <> row
  <> ")), sqlight.Error),\n"
  <> "    read_one: fn(Int) -> Result(Option("
  <> row
  <> "), sqlight.Error),\n"
  <> "    read_many: fn(\n"
  <> "      filter.FilterArg("
  <> fl
  <> ", NumRefOrValue, StringRefOrValue, "
  <> fe
  <> "),\n"
  <> "    ) -> Result(List("
  <> row
  <> "), sqlight.Error),\n"
  <> "    delete_one: fn(Int) -> Result(Nil, sqlight.Error),\n"
  <> "    delete_many: fn(List(Int)) -> Result(Nil, sqlight.Error),\n"
  <> "  )\n"
  <> "}\n"
  <> "\n"
  <> "pub fn "
  <> decoder_fn
  <> "() -> decode.Decoder("
  <> row
  <> ") {\n"
  <> decoder_lines
  <> "}\n"
}

fn filterable_record(ctx: SchemaContext) -> String {
  let fl = ctx.filterable_name
  let field_lines =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      let ref = case sql_types.filter_is_string_column(typ) {
        True -> "StringRefOrValue"
        False -> "NumRefOrValue"
      }
      "    " <> label <> ": " <> ref <> ",\n"
    })
    |> string.concat
  "  "
    <> fl
    <> "(\n"
    <> field_lines
    <> "    id: NumRefOrValue,\n"
    <> "    created_at: NumRefOrValue,\n"
    <> "    updated_at: NumRefOrValue,\n"
    <> "    deleted_at: NumRefOrValue,\n"
    <> "  )\n"
}

fn numeric_schema_fields(ctx: SchemaContext) -> List(#(String, glance.Type)) {
  list.filter(ctx.fields, fn(pair) {
    !sql_types.filter_is_string_column(pair.1)
  })
}

fn string_schema_fields(ctx: SchemaContext) -> List(#(String, glance.Type)) {
  list.filter(ctx.fields, fn(pair) { sql_types.filter_is_string_column(pair.1) })
}

fn num_field_enum(ctx: SchemaContext) -> String {
  let schema_lines =
    list.map(numeric_schema_fields(ctx), fn(pair) {
      "  " <> pascal_case_field_label(pair.0) <> "Int\n"
    })
    |> string.concat
  schema_lines
  <> "  IdInt\n"
  <> "  CreatedAtInt\n"
  <> "  UpdatedAtInt\n"
  <> "  DeletedAtInt\n"
}

fn string_field_enum(ctx: SchemaContext) -> String {
  let fields = string_schema_fields(ctx)
  list.map(fields, fn(pair) { "  " <> pascal_case_field_label(pair.0) <> "String\n" })
  |> string.concat
}

fn full_field_enum(ctx: SchemaContext) -> String {
  let schema_lines =
    list.map(ctx.fields, fn(pair) { "  " <> pascal_case_field_label(pair.0) <> "Field\n" })
    |> string.concat
  schema_lines
  <> "  IdField\n"
  <> "  CreatedAtField\n"
  <> "  UpdatedAtField\n"
  <> "  DeletedAtField\n"
}

fn row_decoder_body(ctx: SchemaContext) -> String {
  let value_fields =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      let dec = sql_types.decode_expression(typ)
      "  use " <> label <> " <- decode.field("
      <> int_to_string(4 + field_index(ctx.fields, label))
      <> ", "
      <> dec
      <> ")\n"
    })
    |> string.concat
  let value_ctor =
    "  decode.success("
    <> ctx.row_name
    <> "(\n"
    <> "    value: "
    <> ctx.variant_name
    <> "("
    <> join_label_value_pairs(ctx.fields)
    <> "),\n"
    <> "    id:,\n"
    <> "    created_at:,\n"
    <> "    updated_at:,\n"
    <> "    deleted_at:,\n"
    <> "  ))\n"
  "  use id <- decode.field(0, decode.int)\n"
  <> "  use created_at <- decode.field(1, decode.int)\n"
  <> "  use updated_at <- decode.field(2, decode.int)\n"
  <> "  use deleted_at <- decode.field(3, decode.optional(decode.int))\n"
  <> value_fields
  <> value_ctor
}

fn field_index(fields: List(#(String, a)), label: String) -> Int {
  field_index_loop(fields, label, 0)
}

fn field_index_loop(fields: List(#(String, a)), label: String, i: Int) -> Int {
  case fields {
    [] -> 0
    [#(l, _), ..rest] ->
      case l == label {
        True -> i
        False -> field_index_loop(rest, label, i + 1)
      }
  }
}

fn join_label_value_pairs(fields: List(#(String, a))) -> String {
  case fields {
    [] -> ""
    [#(l, _), ..rest] ->
      l
      <> ": "
      <> l
      <> case rest {
        [] -> ""
        _ -> ", " <> join_label_value_pairs(rest)
      }
  }
}

fn int_to_string(i: Int) -> String {
  int.to_string(i)
}
