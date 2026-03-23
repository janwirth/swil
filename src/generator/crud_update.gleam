import glance
import gleam/list
import gleam/string

import generator/crud_read
import generator/schema_context.{type SchemaContext}
import generator/sql_types

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let schema_mod = ctx.schema_module
  let t = ctx.type_name
  let row = ctx.row_name
  let table = ctx.table
  let singular = ctx.singular
  let cols = update_select_column_names(ctx)
  let decoder = ctx.singular <> "_row_decoder"
  let field_lines =
    list.map(ctx.fields, fn(pair) {
      update_field_step_lines(singular, pair.0, pair.1)
    })
    |> string.concat
  let select_try = crud_read.render_read_one_try_body(table, cols, decoder)
  "import cake/select\n"
  <> "import cake/update as cake_update\n"
  <> "import cake/where\n"
  <> "import gleam/dynamic/decode\n"
  <> "import gleam/list\n"
  <> "import gleam/option.{type Option, None, Some}\n"
  <> "import gleam/result\n"
  <> "import gleam/time/timestamp\n"
  <> "import sqlight\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/structure.{type "
  <> row
  <> ", "
  <> decoder
  <> "}\n"
  <> "import "
  <> schema_mod
  <> ".{type "
  <> t
  <> "}\n"
  <> "import help/cake_sql_exec\n"
  <> "\n"
  <> "pub fn update_one(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  id: Int,\n"
  <> "  "
  <> singular
  <> ": "
  <> schema_mod
  <> "."
  <> t
  <> ",\n"
  <> ") -> Result(Option("
  <> row
  <> "), sqlight.Error) {\n"
  <> "  use _ <- result.try({\n"
  <> "    let #(now_sec, _) =\n"
  <> "      timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())\n"
  <> "    let u = cake_update.table(cake_update.new(), \""
  <> table
  <> "\")\n"
  <> field_lines
  <> "    let u =\n"
  <> "      cake_update.set(u, cake_update.set_int(\"updated_at\", now_sec))\n"
  <> "    let q =\n"
  <> "      cake_update.to_query(\n"
  <> "        cake_update.where(\n"
  <> "          u,\n"
  <> "          where.and([\n"
  <> "            where.eq(where.col(\"id\"), where.int(id)),\n"
  <> "            where.is_null(where.col(\"deleted_at\")),\n"
  <> "          ]),\n"
  <> "        ),\n"
  <> "      )\n"
  <> "    cake_sql_exec.run_write_query(q, decode.success(Nil), conn)\n"
  <> "  })\n"
  <> "  use rows <- result.try({\n"
  <> "    "
  <> select_try
  <> "\n"
  <> "  })\n"
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

fn update_select_column_names(ctx: SchemaContext) -> List(String) {
  let rest = list.map(ctx.fields, fn(pair) { pair.0 })
  ["id", "created_at", "updated_at", "deleted_at", ..rest]
}

fn update_field_step_lines(
  singular: String,
  label: String,
  typ: glance.Type,
) -> String {
  let r = sql_types.rendered_type(typ)
  case r {
    "Int" ->
      "    let u = cake_update.set(u, cake_update.set_int(\""
      <> label
      <> "\", "
      <> singular
      <> "."
      <> label
      <> "))\n"
    "Float" ->
      "    let u = cake_update.set(u, cake_update.set_float(\""
      <> label
      <> "\", "
      <> singular
      <> "."
      <> label
      <> "))\n"
    "Bool" ->
      "    let u = cake_update.set(u, cake_update.set_bool(\""
      <> label
      <> "\", "
      <> singular
      <> "."
      <> label
      <> "))\n"
    "String" ->
      "    let u = cake_update.set(u, cake_update.set_string(\""
      <> label
      <> "\", "
      <> singular
      <> "."
      <> label
      <> "))\n"
    "Option(Int)" ->
      update_option_lines(singular, label, "set_int", "v")
    "Option(Float)" ->
      update_option_lines(singular, label, "set_float", "v")
    "Option(Bool)" ->
      update_option_lines(singular, label, "set_bool", "v")
    "Option(String)" ->
      update_option_lines(singular, label, "set_string", "v")
    _ ->
      "    let u = cake_update.set(u, cake_update.set_string(\""
      <> label
      <> "\", \"\")\n"
  }
}

fn update_option_lines(
  singular: String,
  label: String,
  set_fn: String,
  var: String,
) -> String {
  "    let u = case "
  <> singular
  <> "."
  <> label
  <> " {\n"
  <> "      Some("
  <> var
  <> ") -> cake_update.set(u, cake_update."
  <> set_fn
  <> "(\""
  <> label
  <> "\", "
  <> var
  <> "))\n"
  <> "      None -> cake_update.set(u, cake_update.set_null(\""
  <> label
  <> "\"))\n"
  <> "    }\n"
}
