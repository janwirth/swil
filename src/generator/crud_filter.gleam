//// `crud/filter` module text plus gleamgen `cake/where` + `cake/fragment` helpers.

import cake/where

import glance
import gleam/list
import gleam/option.{Some}
import gleam/string

import generator/gleam_format_helpers
import generator/schema_context.{type SchemaContext, pascal_case_field_label}
import generator/sql_types

import gleamgen/expression as gex
import gleamgen/expression/case_ as gcase
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/render as grender
import gleamgen/types as gtypes

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let fl = ctx.filterable_name
  let fe = ctx.field_enum_name
  let imp = filter_import_block(ctx)
  let filterable_body = filterable_refs_body(ctx)
  "import cake/fragment.{\n"
  <> "  literal as frag_literal, placeholder as frag_ph, prepared as frag_prepared,\n"
  <> "  string as frag_string,\n"
  <> "}\n"
  <> "import cake/where\n"
  <> "import gleam/option.{type Option, None, Some}\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/structure.{\n"
  <> imp
  <> "\n}\n"
  <> "import help/filter\n"
  <> "\n"
  <> "pub type Filter =\n"
  <> "  fn("
  <> fl
  <> ") -> filter.BoolExpr(NumRefOrValue, StringRefOrValue)\n"
  <> "\n"
  <> "pub fn filter_arg(\n"
  <> "  nullable_filter: Option(Filter),\n"
  <> "  sort: Option(filter.SortOrder("
  <> fe
  <> ")),\n"
  <> ") -> filter.FilterArg("
  <> fl
  <> ", NumRefOrValue, StringRefOrValue, "
  <> fe
  <> ") {\n"
  <> "  case nullable_filter {\n"
  <> "    Some(f) -> filter.FilterArg(filter: f, sort: sort)\n"
  <> "    None -> filter.NoFilter(sort: sort)\n"
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "pub fn filterable_refs() -> "
  <> fl
  <> " {\n"
  <> "  "
  <> fl
  <> "(\n"
  <> filterable_body
  <> "  )\n"
  <> "}\n"
  <> "\n"
  <> "fn num_operand_where_value(op: NumRefOrValue) -> where.WhereValue {\n"
  <> "  case op {\n"
  <> num_where_cases(ctx)
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "fn string_operand_part(op: StringRefOrValue) -> #(Bool, String) {\n"
  <> "  case op {\n"
  <> string_part_cases(ctx)
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> filter_render_instr_where_fn()
  <> "\n"
  <> "pub fn bool_expr_where(\n"
  <> "  expr: filter.BoolExpr(NumRefOrValue, StringRefOrValue),\n"
  <> ") -> where.Where {\n"
  <> "  case expr {\n"
  <> filter_render_bool_expr_where_case_lines()
  <> "  }\n"
  <> "}\n"
}

fn filter_import_block(ctx: SchemaContext) -> String {
  let type_line =
    "  type "
    <> ctx.field_enum_name
    <> ", type "
    <> ctx.filterable_name
    <> ", type NumRefOrValue, type StringRefOrValue,"
  let value_items = sorted_value_constructor_names(ctx)
  let value_lines =
    gleam_format_helpers.comma_wrap_lines(
      "  ",
      value_items,
      gleam_format_helpers.import_list_max_col,
    )
  type_line <> "\n" <> value_lines
}

fn sorted_value_constructor_names(ctx: SchemaContext) -> List(String) {
  let schema_nums =
    list.map(numeric_fields(ctx), fn(pair) {
      pascal_case_field_label(pair.0) <> "Int"
    })
  let system_nums =
    list.map(["CreatedAt", "DeletedAt", "Id", "UpdatedAt"], fn(s) { s <> "Int" })
  let schema_strs =
    list.map(string_fields(ctx), fn(pair) {
      pascal_case_field_label(pair.0) <> "String"
    })
  let refs = ["NumRef", "NumValue", "StringRef", "StringValue"]
  list.append(schema_nums, system_nums)
  |> list.append(schema_strs)
  |> list.append([ctx.filterable_name])
  |> list.append(refs)
  |> list.sort(by: string.compare)
}

fn numeric_fields(ctx: SchemaContext) -> List(#(String, glance.Type)) {
  list.filter(ctx.fields, fn(p) { !sql_types.filter_is_string_column(p.1) })
}

fn string_fields(ctx: SchemaContext) -> List(#(String, glance.Type)) {
  list.filter(ctx.fields, fn(p) { sql_types.filter_is_string_column(p.1) })
}

fn filterable_refs_body(ctx: SchemaContext) -> String {
  let lines =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      let rhs = case sql_types.filter_is_string_column(typ) {
        True -> "StringRef(" <> pascal_case_field_label(label) <> "String)"
        False -> "NumRef(" <> pascal_case_field_label(label) <> "Int)"
      }
      "    " <> label <> ": " <> rhs <> ",\n"
    })
    |> string.concat
  lines
  <> "    id: NumRef(IdInt),\n"
  <> "    created_at: NumRef(CreatedAtInt),\n"
  <> "    updated_at: NumRef(UpdatedAtInt),\n"
  <> "    deleted_at: NumRef(DeletedAtInt),\n"
}

fn num_where_cases(ctx: SchemaContext) -> String {
  let schema =
    list.map(numeric_fields(ctx), fn(pair) {
      "    NumRef("
      <> pascal_case_field_label(pair.0)
      <> "Int) -> "
      <> filter_render_where_col(pair.0)
      <> "\n"
    })
    |> string.concat
  schema
  <> "    NumRef(IdInt) -> "
  <> filter_render_where_col("id")
  <> "\n"
  <> "    NumRef(CreatedAtInt) -> "
  <> filter_render_where_col("created_at")
  <> "\n"
  <> "    NumRef(UpdatedAtInt) -> "
  <> filter_render_where_col("updated_at")
  <> "\n"
  <> "    NumRef(DeletedAtInt) -> "
  <> filter_render_where_col("deleted_at")
  <> "\n"
  <> "    NumValue(value: v) -> "
  <> filter_render_where_int_v()
  <> "\n"
}

fn string_part_cases(ctx: SchemaContext) -> String {
  let schema =
    list.map(string_fields(ctx), fn(pair) {
      "    StringRef("
      <> pascal_case_field_label(pair.0)
      <> "String) -> #(True, \""
      <> pair.0
      <> "\")\n"
    })
    |> string.concat
  schema <> "    StringValue(value: s) -> #(False, s)\n"
}

// --- gleamgen cake/where + fragment (inline; was crud_filter_cake) ---

fn filter_rctx() {
  grender.default_context()
}

fn filter_rex(e: gex.Expression(t)) -> String {
  gex.render(e, filter_rctx()) |> grender.to_string()
}

fn filter_where_mod() {
  gim.new(["cake", "where"])
}

fn filter_w_col() {
  gim.function1(filter_where_mod(), where.col)
}

fn filter_w_int() {
  gim.function1(filter_where_mod(), where.int)
}

fn filter_w_eq() {
  gim.function2(filter_where_mod(), where.eq)
}

fn filter_w_gt() {
  gim.function2(filter_where_mod(), where.gt)
}

fn filter_w_not() {
  gim.function1(filter_where_mod(), where.not)
}

fn filter_w_and() {
  gim.function1(filter_where_mod(), where.and)
}

fn filter_w_or() {
  gim.function1(filter_where_mod(), where.or)
}

fn filter_w_fragment() {
  gim.function1(filter_where_mod(), where.fragment)
}

fn filter_frag_lit() {
  gex.raw("frag_literal")
}

fn filter_frag_prep() {
  gex.raw("frag_prepared")
}

fn filter_frag_str() {
  gex.raw("frag_string")
}

fn filter_frag_ph() {
  gex.raw("frag_ph")
}

fn filter_concat_str(parts: List(gex.Expression(String))) -> gex.Expression(String) {
  let assert [first, ..rest] = parts
  list.fold(rest, first, fn(acc, p) { gex.concat_string(acc, p) })
}

fn filter_render_where_col(column: String) -> String {
  filter_rex(gex.call1(filter_w_col(), gex.string(column)))
}

fn filter_render_where_int_v() -> String {
  filter_rex(gex.call1(filter_w_int(), gex.raw("v")))
}

fn filter_render_instr_where_fn() -> String {
  let bool_string = gtypes.tuple2(gtypes.bool, gtypes.string)
  let where_ret = gtypes.custom_type(Some("where"), "Where", [])
  let f =
    gfun.new2(
      gparam.new("left", bool_string),
      gparam.new("right", bool_string),
      where_ret,
      fn(left, right) {
        gcase.new(gex.tuple2(left, right))
        |> gcase.with_pattern(
          gpat.tuple2(
            gpat.tuple2(gpat.bool_literal(True), gpat.variable("lc")),
            gpat.tuple2(gpat.bool_literal(True), gpat.variable("rc")),
          ),
          fn(pair) {
            let #(#(_, lc), #(_, rc)) = pair
            let template =
              filter_concat_str([
                gex.string("instr("),
                lc,
                gex.string(", "),
                rc,
                gex.string(") = 0"),
              ])
            gex.call1(filter_w_fragment(), gex.call1(filter_frag_lit(), template))
          },
        )
        |> gcase.with_pattern(
          gpat.tuple2(
            gpat.tuple2(gpat.bool_literal(True), gpat.variable("lc")),
            gpat.tuple2(gpat.bool_literal(False), gpat.variable("rv")),
          ),
          fn(pair) {
            let #(#(_, lc), #(_, rv)) = pair
            let sql =
              filter_concat_str([
                gex.string("instr("),
                lc,
                gex.string(", "),
                filter_frag_ph(),
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(filter_frag_prep(), sql, gex.list([gex.call1(filter_frag_str(), rv)]))
            gex.call1(filter_w_fragment(), prepared)
          },
        )
        |> gcase.with_pattern(
          gpat.tuple2(
            gpat.tuple2(gpat.bool_literal(False), gpat.variable("lv")),
            gpat.tuple2(gpat.bool_literal(True), gpat.variable("rc")),
          ),
          fn(pair) {
            let #(#(_, lv), #(_, rc)) = pair
            let sql =
              filter_concat_str([
                gex.string("instr("),
                filter_frag_ph(),
                gex.string(", "),
                rc,
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(filter_frag_prep(), sql, gex.list([gex.call1(filter_frag_str(), lv)]))
            gex.call1(filter_w_fragment(), prepared)
          },
        )
        |> gcase.with_pattern(
          gpat.tuple2(
            gpat.tuple2(gpat.bool_literal(False), gpat.variable("lv")),
            gpat.tuple2(gpat.bool_literal(False), gpat.variable("rv")),
          ),
          fn(pair) {
            let #(#(_, lv), #(_, rv)) = pair
            let sql =
              filter_concat_str([
                gex.string("instr("),
                filter_frag_ph(),
                gex.string(", "),
                filter_frag_ph(),
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(
                filter_frag_prep(),
                sql,
                gex.list([gex.call1(filter_frag_str(), lv), gex.call1(filter_frag_str(), rv)]),
              )
            gex.call1(filter_w_fragment(), prepared)
          },
        )
        |> gcase.build_expression()
      },
    )
  string.concat([
    grender.to_string(gfun.render(f, filter_rctx(), Some("instr_where"))),
    "\n",
  ])
}

fn filter_render_bool_expr_where_case_lines() -> String {
  let b = gex.raw("bool_expr_where")
  let n = gex.raw("num_operand_where_value")
  let s = gex.raw("string_operand_part")
  let i = gex.raw("instr_where")
  let one = gex.call1(filter_w_int(), gex.int(1))
  let zero = gex.call1(filter_w_int(), gex.int(0))
  string.concat([
    "    filter.LiteralTrue -> ",
    filter_rex(gex.call2(filter_w_eq(), one, one)),
    "\n    filter.LiteralFalse -> ",
    filter_rex(gex.call2(filter_w_eq(), one, zero)),
    "\n    filter.Not(inner) -> ",
    filter_rex(gex.call1(filter_w_not(), gex.call1(b, gex.raw("inner")))),
    "\n    filter.And(left, right) ->\n      ",
    filter_rex(
      gex.call1(
        filter_w_and(),
        gex.list([
          gex.call1(b, gex.raw("left")),
          gex.call1(b, gex.raw("right")),
        ]),
      ),
    ),
    "\n    filter.Or(left, right) ->\n      ",
    filter_rex(
      gex.call1(
        filter_w_or(),
        gex.list([
          gex.call1(b, gex.raw("left")),
          gex.call1(b, gex.raw("right")),
        ]),
      ),
    ),
    "\n    filter.Gt(left, right) ->\n      ",
    filter_rex(
      gex.call2(
        filter_w_gt(),
        gex.call1(n, gex.raw("left")),
        gex.call1(n, gex.raw("right")),
      ),
    ),
    "\n    filter.Eq(left, right) ->\n      ",
    filter_rex(
      gex.call2(
        filter_w_eq(),
        gex.call1(n, gex.raw("left")),
        gex.call1(n, gex.raw("right")),
      ),
    ),
    "\n    filter.Ne(left, right) ->\n      ",
    filter_rex(
      gex.call1(
        filter_w_not(),
        gex.call2(
          filter_w_eq(),
          gex.call1(n, gex.raw("left")),
          gex.call1(n, gex.raw("right")),
        ),
      ),
    ),
    "\n    filter.NotContains(left, right) ->\n      ",
    filter_rex(
      gex.call2(
        i,
        gex.call1(s, gex.raw("left")),
        gex.call1(s, gex.raw("right")),
      ),
    ),
    "\n",
  ])
}

