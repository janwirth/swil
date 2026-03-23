import gleam/list
import gleam/string

import generator/gleam_format_helpers
import generator/schema_context.{type SchemaContext, pascal_case_field_label}

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let fe = ctx.field_enum_name
  let import_body = sort_structure_import_block(fe, all_field_variant_names(ctx))
  let cases = field_sql_cases(ctx)
  string.concat([
    "import ",
    layer,
    "/structure.{\n",
    import_body,
    "\n}\n",
    "\n",
    "pub fn ",
    singular_field_fn(ctx),
    "(field: ",
    fe,
    ") -> String {\n",
    "  case field {\n",
    cases,
    "  }\n",
    "}\n",
  ])
}

fn singular_field_fn(ctx: SchemaContext) -> String {
  string.concat([ctx.singular, "_field_sql"])
}

fn sort_structure_import_block(
  field_enum: String,
  variant_names: List(String),
) -> String {
  gleam_format_helpers.comma_wrap_lines(
    "  ",
    [string.concat(["type ", field_enum]), ..variant_names],
    gleam_format_helpers.import_list_max_col,
  )
}

fn all_field_variant_names(ctx: SchemaContext) -> List(String) {
  let schema =
    list.map(ctx.fields, fn(pair) {
      string.concat([pascal_case_field_label(pair.0), "Field"])
    })
  let system =
    list.map(["Id", "CreatedAt", "UpdatedAt", "DeletedAt"], fn(s) {
      string.concat([s, "Field"])
    })
  list.sort(list.append(schema, system), by: string.compare)
}

fn field_sql_cases(ctx: SchemaContext) -> String {
  let schema_cases =
    list.map(ctx.fields, fn(pair) {
      let #(label, _) = pair
      string.concat([
        "    ",
        pascal_case_field_label(label),
        "Field -> \"",
        label,
        "\"\n",
      ])
    })
    |> string.concat
  string.concat([
    schema_cases,
    "    IdField -> \"id\"\n",
    "    CreatedAtField -> \"created_at\"\n",
    "    UpdatedAtField -> \"updated_at\"\n",
    "    DeletedAtField -> \"deleted_at\"\n",
  ])
}
