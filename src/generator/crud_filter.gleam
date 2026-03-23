import glance
import gleam/list
import gleam/string

import generator/gleam_format_helpers
import generator/schema_context.{type SchemaContext, pascal_case_field_label}
import generator/sql_types

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let fl = ctx.filterable_name
  let fe = ctx.field_enum_name
  let imp = filter_import_block(ctx)
  let filterable_body = filterable_refs_body(ctx)
  let num_cases = num_operand_cases(ctx)
  let str_cases = string_operand_cases(ctx)
  "import gleam/list\n"
  <> "import gleam/option.{type Option, None, Some}\n"
  <> "import sqlight\n"
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
  <> "fn num_operand_sql(op: NumRefOrValue) -> #(String, List(sqlight.Value)) {\n"
  <> "  case op {\n"
  <> num_cases
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "fn string_operand_sql(op: StringRefOrValue) -> #(String, List(sqlight.Value)) {\n"
  <> "  case op {\n"
  <> str_cases
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "pub fn bool_expr_sql(\n"
  <> "  expr: filter.BoolExpr(NumRefOrValue, StringRefOrValue),\n"
  <> ") -> #(String, List(sqlight.Value)) {\n"
  <> "  case expr {\n"
  <> "    filter.LiteralTrue -> #(\"1 = 1\", [])\n"
  <> "    filter.LiteralFalse -> #(\"1 = 0\", [])\n"
  <> "    filter.Not(inner) -> {\n"
  <> "      let #(s, p) = bool_expr_sql(inner)\n"
  <> "      #(\"not (\" <> s <> \")\", p)\n"
  <> "    }\n"
  <> "    filter.And(left, right) -> {\n"
  <> "      let #(ls, lp) = bool_expr_sql(left)\n"
  <> "      let #(rs, rp) = bool_expr_sql(right)\n"
  <> "      #(\"(\" <> ls <> \") and (\" <> rs <> \")\", list.append(lp, rp))\n"
  <> "    }\n"
  <> "    filter.Or(left, right) -> {\n"
  <> "      let #(ls, lp) = bool_expr_sql(left)\n"
  <> "      let #(rs, rp) = bool_expr_sql(right)\n"
  <> "      #(\"(\" <> ls <> \") or (\" <> rs <> \")\", list.append(lp, rp))\n"
  <> "    }\n"
  <> "    filter.Gt(left, right) -> {\n"
  <> "      let #(ls, lp) = num_operand_sql(left)\n"
  <> "      let #(rs, rp) = num_operand_sql(right)\n"
  <> "      #(ls <> \" > \" <> rs, list.append(lp, rp))\n"
  <> "    }\n"
  <> "    filter.Eq(left, right) -> {\n"
  <> "      let #(ls, lp) = num_operand_sql(left)\n"
  <> "      let #(rs, rp) = num_operand_sql(right)\n"
  <> "      #(ls <> \" = \" <> rs, list.append(lp, rp))\n"
  <> "    }\n"
  <> "    filter.Ne(left, right) -> {\n"
  <> "      let #(ls, lp) = num_operand_sql(left)\n"
  <> "      let #(rs, rp) = num_operand_sql(right)\n"
  <> "      #(ls <> \" <> \" <> rs, list.append(lp, rp))\n"
  <> "    }\n"
  <> "    filter.NotContains(left, right) -> {\n"
  <> "      let #(ls, lp) = string_operand_sql(left)\n"
  <> "      let #(rs, rp) = string_operand_sql(right)\n"
  <> "      #(\"instr(\" <> ls <> \", \" <> rs <> \") = 0\", list.append(lp, rp))\n"
  <> "    }\n"
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

fn num_operand_cases(ctx: SchemaContext) -> String {
  let schema =
    list.map(numeric_fields(ctx), fn(pair) {
      "    NumRef("
      <> pascal_case_field_label(pair.0)
      <> "Int) -> #(\""
      <> pair.0
      <> "\", [])\n"
    })
    |> string.concat
  schema
  <> "    NumRef(IdInt) -> #(\"id\", [])\n"
  <> "    NumRef(CreatedAtInt) -> #(\"created_at\", [])\n"
  <> "    NumRef(UpdatedAtInt) -> #(\"updated_at\", [])\n"
  <> "    NumRef(DeletedAtInt) -> #(\"deleted_at\", [])\n"
  <> "    NumValue(value: v) -> #(\"?\", [sqlight.int(v)])\n"
}

fn string_operand_cases(ctx: SchemaContext) -> String {
  let schema =
    list.map(string_fields(ctx), fn(pair) {
      "    StringRef("
      <> pascal_case_field_label(pair.0)
      <> "String) -> #(\""
      <> pair.0
      <> "\", [])\n"
    })
    |> string.concat
  schema <> "    StringValue(value: s) -> #(\"?\", [sqlight.text(s)])\n"
}
