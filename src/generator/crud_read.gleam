import gleam/list
import gleam/string

import generator/gleam_format_helpers
import generator/schema_context.{type SchemaContext}

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let fl = ctx.filterable_name
  let fe = ctx.field_enum_name
  let row = ctx.row_name
  let table = ctx.table
  let cols = select_column_names(ctx)
  let decoder = ctx.singular <> "_row_decoder"
  let read_type_block = [
    "type " <> fe,
    "type " <> row,
    "type " <> fl,
    "type NumRefOrValue",
  ]
  let read_value_block = ["type StringRefOrValue", decoder]
  let import_inner =
    gleam_format_helpers.comma_wrap_lines(
      "  ",
      read_type_block,
      gleam_format_helpers.import_list_max_col,
    )
    <> "\n"
    <> gleam_format_helpers.comma_wrap_lines(
      "  ",
      read_value_block,
      gleam_format_helpers.import_list_max_col,
    )
  let select_expr = read_one_select_expression(table, cols, decoder)
  "import cake/select\n"
  <> "import cake/where\n"
  <> "import gleam/dynamic/decode\n"
  <> "import gleam/option.{type Option, None, Some}\n"
  <> "import gleam/result\n"
  <> "import sqlight\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/crud/filter as crud_filter\n"
  <> "import "
  <> layer
  <> "/crud/sort as crud_sort\n"
  <> "import "
  <> layer
  <> "/structure.{\n"
  <> import_inner
  <> "\n}\n"
  <> "import help/cake_sql_exec\n"
  <> "import help/filter\n"
  <> "\n"
  <> "pub fn read_one(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  id: Int,\n"
  <> ") -> Result(Option("
  <> row
  <> "), sqlight.Error) {\n"
  <> "  use rows <- result.try({\n"
  <> select_expr
  <> "  })\n"
  <> "  case rows {\n"
  <> "    [row, ..] -> Ok(Some(row))\n"
  <> "    [] -> Ok(None)\n"
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "fn read_many_sql(\n"
  <> "  arg: filter.FilterArg(\n"
  <> "    "
  <> fl
  <> ",\n"
  <> "    NumRefOrValue,\n"
  <> "    StringRefOrValue,\n"
  <> "    "
  <> fe
  <> ",\n"
  <> "  ),\n"
  <> ") -> #(String, List(sqlight.Value)) {\n"
  <> "  let base =\n"
  <> "    \"select "
  <> string.join(cols, ", ")
  <> " from "
  <> table
  <> " where deleted_at is null and \"\n"
  <> "  case arg {\n"
  <> "    filter.NoFilter(sort: s) -> #(\n"
  <> "      base <> \"1 = 1\" <> crud_sort.sort_clause(s),\n"
  <> "      [],\n"
  <> "    )\n"
  <> "    filter.FilterArg(filter: f, sort: s) -> {\n"
  <> "      let #(cond, params) =\n"
  <> "        crud_filter.bool_expr_sql(f(crud_filter.filterable_refs()))\n"
  <> "      #(base <> \"(\" <> cond <> \")\" <> crud_sort.sort_clause(s), params)\n"
  <> "    }\n"
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "pub fn read_many(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  arg: filter.FilterArg(\n"
  <> "    "
  <> fl
  <> ",\n"
  <> "    NumRefOrValue,\n"
  <> "    StringRefOrValue,\n"
  <> "    "
  <> fe
  <> ",\n"
  <> "  ),\n"
  <> ") -> Result(List("
  <> row
  <> "), sqlight.Error) {\n"
  <> "  let #(sql, params) = read_many_sql(arg)\n"
  <> "  sqlight.query(sql, on: conn, with: params, expecting: "
  <> decoder
  <> "())\n"
  <> "}\n"
}

fn select_column_names(ctx: SchemaContext) -> List(String) {
  let rest = list.map(ctx.fields, fn(pair) { pair.0 })
  ["id", "created_at", "updated_at", "deleted_at", ..rest]
}

fn read_one_select_expression(
  table: String,
  cols: List(String),
  decoder: String,
) -> String {
  let from_tbl =
    "    select.new()\n"
    <> "    |> select.from_table(\""
    <> table
    <> "\")\n"
  let cols_part =
    list.fold(cols, "", fn(acc, col) {
      acc
      <> "    |> select.select_col(\""
      <> col
      <> "\")\n"
    })
  from_tbl
  <> cols_part
  <> "    |> select.where(\n"
  <> "      where.and([\n"
  <> "        where.eq(where.col(\"id\"), where.int(id)),\n"
  <> "        where.is_null(where.col(\"deleted_at\")),\n"
  <> "      ]),\n"
  <> "    )\n"
  <> "    |> select.to_query\n"
  <> "    |> cake_sql_exec.run_read_query("
  <> decoder
  <> "(), conn)\n"
}
