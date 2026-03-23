import gleam/list
import gleam/string

import generator/schema_context.{type SchemaContext}
import generator/sqlight_param

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let t = ctx.type_name
  let row = ctx.row_name
  let table = ctx.table
  let singular = ctx.singular
  let set_clause = update_set_clause(ctx)
  let bindings = update_bindings_list(ctx)
  let cols = select_columns(ctx)
  let decoder = ctx.singular <> "_row_decoder"
  "import gleam/dynamic/decode\n"
  <> "import gleam/list\n"
  <> "import gleam/option.{type Option, None, Some}\n"
  <> "import gleam/result\n"
  <> "import sqlight\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/resource.{type "
  <> t
  <> "}\n"
  <> "import "
  <> layer
  <> "/structure.{type "
  <> row
  <> ", "
  <> decoder
  <> "}\n"
  <> "\n"
  <> "pub fn update_one(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  id: Int,\n"
  <> "  "
  <> singular
  <> ": "
  <> t
  <> ",\n"
  <> ") -> Result(Option("
  <> row
  <> "), sqlight.Error) {\n"
  <> "  use _ <- result.try(sqlight.query(\n"
  <> "    \"update "
  <> table
  <> " set "
  <> set_clause
  <> ", updated_at = ? where id = ? and deleted_at is null\",\n"
  <> "    on: conn,\n"
  <> "    with: [\n"
  <> bindings
  <> "      sqlight.int(1),\n"
  <> "      sqlight.int(id),\n"
  <> "    ],\n"
  <> "    expecting: decode.success(Nil),\n"
  <> "  ))\n"
  <> "  use rows <- result.try(sqlight.query(\n"
  <> "    \"select "
  <> cols
  <> " from "
  <> table
  <> " where id = ? and deleted_at is null limit 1\",\n"
  <> "    on: conn,\n"
  <> "    with: [sqlight.int(id)],\n"
  <> "    expecting: "
  <> decoder
  <> "(),\n"
  <> "  ))\n"
  <> "  case rows {\n"
  <> "    [row, ..] -> Ok(Some(row))\n"
  <> "    [] -> Ok(None)\n"
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "pub fn update_many(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  rows: List(#(Int, "
  <> t
  <> ")),\n"
  <> ") -> Result(List(Option("
  <> row
  <> ")), sqlight.Error) {\n"
  <> "  list.try_map(over: rows, with: fn(row) {\n"
  <> "    let #(id, "
  <> singular
  <> ") = row\n"
  <> "    update_one(conn, id, "
  <> singular
  <> ")\n"
  <> "  })\n"
  <> "}\n"
}

fn update_set_clause(ctx: SchemaContext) -> String {
  list.map(ctx.fields, fn(pair) { pair.0 <> " = ?" })
  |> string.join(", ")
}

fn update_bindings_list(ctx: SchemaContext) -> String {
  list.map(ctx.fields, fn(pair) {
    let #(label, typ) = pair
    "      "
    <> sqlight_param.from_record_field(ctx.singular, label, typ)
    <> ",\n"
  })
  |> string.concat
}

fn select_columns(ctx: SchemaContext) -> String {
  let rest =
    list.map(ctx.fields, fn(pair) { pair.0 })
    |> string.join(", ")
  "id, created_at, updated_at, deleted_at, " <> rest
}
