import gleam/list

import generator/crud_read_cake
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
  let select_expr =
    "    "
    <> crud_read_cake.render_read_one_try_body(table, cols, decoder)
    <> "\n"
  let read_many_block = read_many_section(ctx)
  "import cake/select\n"
  <> "import cake/where\n"
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
  <> read_many_block
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
  <> "  read_many_ordered(arg)\n"
  <> "  |> select.to_query\n"
  <> "  |> cake_sql_exec.run_read_query("
  <> decoder
  <> "(), conn)\n"
  <> "}\n"
}

fn read_many_section(ctx: SchemaContext) -> String {
  let fl = ctx.filterable_name
  let fe = ctx.field_enum_name
  let table = ctx.table
  let cols = select_column_names(ctx)
  let field_sql_fn = ctx.singular <> "_field_sql"
  let base_sel = crud_read_cake.render_read_many_base_select_where(table, cols)
  "fn read_many_filter_where(\n"
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
  <> ") -> where.Where {\n"
  <> "  case arg {\n"
  <> "    filter.NoFilter(..) -> where.eq(where.int(1), where.int(1))\n"
  <> "    filter.FilterArg(filter: f, ..) ->\n"
  <> "      crud_filter.bool_expr_where(f(crud_filter.filterable_refs()))\n"
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "fn read_many_ordered(\n"
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
  <> ") {\n"
  <> "  let order = case arg {\n"
  <> "    filter.NoFilter(sort: s) -> s\n"
  <> "    filter.FilterArg(sort: s, ..) -> s\n"
  <> "  }\n"
  <> "  let base =\n    "
  <> base_sel
  <> "\n"
  <> "  case order {\n"
  <> "    None -> base\n"
  <> "    Some(filter.Asc(f)) ->\n"
  <> "      select.order_by_asc(base, crud_sort."
  <> field_sql_fn
  <> "(f))\n"
  <> "    Some(filter.Desc(f)) ->\n"
  <> "      select.order_by_desc(base, crud_sort."
  <> field_sql_fn
  <> "(f))\n"
  <> "  }\n"
  <> "}\n"
}

fn select_column_names(ctx: SchemaContext) -> List(String) {
  let rest = list.map(ctx.fields, fn(pair) { pair.0 })
  ["id", "created_at", "updated_at", "deleted_at", ..rest]
}

