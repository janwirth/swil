import gleam/list
import gleam/string

import generator/schema_context.{type SchemaContext, pascal_case_field_label}

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let fe = ctx.field_enum_name
  let imports = sorted_imports(ctx)
  let cases = field_sql_cases(ctx)
  "import gleam/option.{type Option, None, Some}\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/structure.{\n"
  <> "  type "
  <> fe
  <> ",\n"
  <> imports
  <> "}\n"
  <> "import help/filter\n"
  <> "\n"
  <> "pub fn "
  <> singular_field_fn(ctx)
  <> "(field: "
  <> fe
  <> ") -> String {\n"
  <> "  case field {\n"
  <> cases
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "pub fn sort_clause(sort: Option(filter.SortOrder("
  <> fe
  <> "))) -> String {\n"
  <> "  case sort {\n"
  <> "    None -> \"\"\n"
  <> "    Some(filter.Asc(f)) -> \" order by \" <> "
  <> singular_field_fn(ctx)
  <> "(f) <> \" asc\"\n"
  <> "    Some(filter.Desc(f)) -> \" order by \" <> "
  <> singular_field_fn(ctx)
  <> "(f) <> \" desc\"\n"
  <> "  }\n"
  <> "}\n"
}

fn singular_field_fn(ctx: SchemaContext) -> String {
  ctx.singular <> "_field_sql"
}

fn sorted_imports(ctx: SchemaContext) -> String {
  let names = all_field_variant_names(ctx)
  list.map(names, fn(n) { "  " <> n <> ",\n" }) |> string.concat
}

fn all_field_variant_names(ctx: SchemaContext) -> List(String) {
  let schema =
    list.map(ctx.fields, fn(pair) { pascal_case_field_label(pair.0) <> "Field" })
  let system =
    list.map(
      ["Id", "CreatedAt", "UpdatedAt", "DeletedAt"],
      fn(s) { s <> "Field" },
    )
  list.sort(list.append(schema, system), by: string.compare)
}

fn field_sql_cases(ctx: SchemaContext) -> String {
  let schema_cases =
    list.map(ctx.fields, fn(pair) {
      let #(label, _) = pair
      "    "
      <> pascal_case_field_label(label)
      <> "Field -> \""
      <> label
      <> "\"\n"
    })
    |> string.concat
  schema_cases
  <> "    IdField -> \"id\"\n"
  <> "    CreatedAtField -> \"created_at\"\n"
  <> "    UpdatedAtField -> \"updated_at\"\n"
  <> "    DeletedAtField -> \"deleted_at\"\n"
}
