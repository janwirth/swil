import gleam/list
import gleam/string

import generator/schema_context.{type SchemaContext}

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let fl = ctx.filterable_name
  let fe = ctx.field_enum_name
  let row = ctx.row_name
  let table = ctx.table
  let cols = select_columns(ctx)
  let decoder = ctx.singular <> "_row_decoder"
  "import gleam/option.{type Option, None, Some}\n"
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
  <> "  type "
  <> fe
  <> ",\n"
  <> "  type "
  <> row
  <> ",\n"
  <> "  type "
  <> fl
  <> ",\n"
  <> "  type NumRefOrValue,\n"
  <> "  type StringRefOrValue,\n"
  <> "  "
  <> decoder
  <> ",\n"
  <> "}\n"
  <> "import help/filter\n"
  <> "\n"
  <> "pub fn read_one(conn: sqlight.Connection, id: Int) -> Result(Option("
  <> row
  <> "), sqlight.Error) {\n"
  <> "  use rows <- result.try(sqlight.query(\n"
  <> "    \"select "
  <> cols
  <> " from "
  <> table
  <> " where id = ? and deleted_at is null\",\n"
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
  <> "fn read_many_sql(\n"
  <> "  arg: filter.FilterArg("
  <> fl
  <> ", NumRefOrValue, StringRefOrValue, "
  <> fe
  <> "),\n"
  <> ") -> #(String, List(sqlight.Value)) {\n"
  <> "  let base =\n"
  <> "    \"select "
  <> cols
  <> " from "
  <> table
  <> " where deleted_at is null and \"\n"
  <> "  case arg {\n"
  <> "    filter.NoFilter(sort: s) -> #(base <> \"1 = 1\" <> crud_sort.sort_clause(s), [])\n"
  <> "    filter.FilterArg(filter: f, sort: s) -> {\n"
  <> "      let #(cond, params) = crud_filter.bool_expr_sql(f(crud_filter.filterable_refs()))\n"
  <> "      #(base <> \"(\" <> cond <> \")\" <> crud_sort.sort_clause(s), params)\n"
  <> "    }\n"
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "pub fn read_many(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  arg: filter.FilterArg("
  <> fl
  <> ", NumRefOrValue, StringRefOrValue, "
  <> fe
  <> "),\n"
  <> ") -> Result(List("
  <> row
  <> "), sqlight.Error) {\n"
  <> "  let #(sql, params) = read_many_sql(arg)\n"
  <> "  sqlight.query(sql, on: conn, with: params, expecting: "
  <> decoder
  <> "())\n"
  <> "}\n"
}

fn select_columns(ctx: SchemaContext) -> String {
  let rest =
    list.map(ctx.fields, fn(pair) { pair.0 })
    |> string.join(", ")
  "id, created_at, updated_at, deleted_at, " <> rest
}
