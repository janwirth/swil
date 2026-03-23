//// Generated `read` modules: `cake/select` + `cake/where` via gleamgen helpers below.

import cake/select
import cake/where

import gleam/list

import generator/gleam_format_helpers
import generator/schema_context.{type SchemaContext}

import gleamgen/expression as gex
import gleamgen/import_ as gim
import gleamgen/render as grender

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
    <> render_read_one_try_body(table, cols, decoder)
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
  let base_sel = render_read_many_base_select_where(table, cols)
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

// --- gleamgen cake/select helpers (inline; was crud_read_cake) ---

fn rctx() {
  grender.default_context()
}

fn rex(e: gex.Expression(t)) -> String {
  gex.render(e, rctx()) |> grender.to_string()
}

fn select_mod() {
  gim.new(["cake", "select"])
}

fn where_mod() {
  gim.new(["cake", "where"])
}

fn w_col() {
  gim.function1(where_mod(), where.col)
}

fn w_int() {
  gim.function1(where_mod(), where.int)
}

fn w_eq() {
  gim.function2(where_mod(), where.eq)
}

fn w_and() {
  gim.function1(where_mod(), where.and)
}

fn w_is_null() {
  gim.function1(where_mod(), where.is_null)
}

fn cake_sql_run_read() {
  gex.raw("cake_sql_exec.run_read_query")
}

pub fn render_read_one_try_body(
  table: String,
  cols: List(String),
  decoder_fn: String,
) -> String {
  let sm = select_mod()
  let s_new = gim.function0(sm, select.new)
  let s_from = gim.function2(sm, select.from_table)
  let s_cols = gim.function2(sm, select.select_cols)
  let s_where = gim.function2(sm, select.where)
  let s_to_q = gim.function1(sm, select.to_query)
  let col_list = list.map(cols, gex.string)
  let sel =
    gex.call2(
      s_cols,
      gex.call2(s_from, gex.call0(s_new), gex.string(table)),
      gex.list(col_list),
    )
  let id_eq =
    gex.call2(
      w_eq(),
      gex.call1(w_col(), gex.string("id")),
      gex.call1(w_int(), gex.raw("id")),
    )
  let deleted_null =
    gex.call1(w_is_null(), gex.call1(w_col(), gex.string("deleted_at")))
  let wh = gex.call1(w_and(), gex.list([id_eq, deleted_null]))
  let sel_w = gex.call2(s_where, sel, wh)
  let q = gex.call1(s_to_q, sel_w)
  let decoder_call = gex.call0(gex.raw(decoder_fn))
  let full =
    gex.call_dynamic(cake_sql_run_read(), [
      q |> gex.to_dynamic,
      decoder_call |> gex.to_dynamic,
      gex.raw("conn") |> gex.to_dynamic,
    ])
  rex(full)
}

pub fn render_read_many_base_select_where(
  table: String,
  cols: List(String),
) -> String {
  let sm = select_mod()
  let s_new = gim.function0(sm, select.new)
  let s_from = gim.function2(sm, select.from_table)
  let s_cols = gim.function2(sm, select.select_cols)
  let s_where = gim.function2(sm, select.where)
  let col_list = list.map(cols, gex.string)
  let sel =
    gex.call2(
      s_cols,
      gex.call2(s_from, gex.call0(s_new), gex.string(table)),
      gex.list(col_list),
    )
  let deleted_null =
    gex.call1(w_is_null(), gex.call1(w_col(), gex.string("deleted_at")))
  let filter_call =
    gex.call1(gex.raw("read_many_filter_where"), gex.raw("arg"))
  let wh = gex.call1(w_and(), gex.list([deleted_null, filter_call]))
  rex(gex.call2(s_where, sel, wh))
}
