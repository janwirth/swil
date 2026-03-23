import gleam/list
import gleam/string

import generator/schema_context.{type SchemaContext}
import generator/sql_types

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let schema_mod = ctx.schema_module
  let t = ctx.type_name
  let singular = ctx.singular
  let table_fn = ctx.table
  let row = ctx.row_name
  let db = ctx.db_type_name
  let filterable = ctx.filterable_name
  let upsert = ctx.for_upsert_type_name
  let field_enum = ctx.field_enum_name
  let num_ref = "Num" <> t <> "Field"
  let str_ref = "String" <> t <> "Field"
  let resource_fields =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      label <> ": " <> sql_types.rendered_type(typ)
    })
    |> string.join(", ")
  "// Main entry for the "
  <> table_fn
  <> " schema: import this module for `"
  <> t
  <> "`, row/db types,\n"
  <> "// `"
  <> table_fn
  <> "` / `migrate_idempotent`, and `"
  <> singular
  <> "` (constructor helper).\n"
  <> "\n"
  <> "import gleam/option.{type Option}\n"
  <> "import sqlight\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/crud\n"
  <> "import "
  <> layer
  <> "/migrate\n"
  <> "import "
  <> layer
  <> "/resource\n"
  <> "import "
  <> layer
  <> "/structure\n"
  <> "import "
  <> schema_mod
  <> ".{type "
  <> t
  <> ", "
  <> ctx.variant_name
  <> "}\n"
  <> "\n"
  <> type_alias_equals(upsert, "resource." <> upsert)
  <> "\n"
  <> type_alias_equals(row, "structure." <> row)
  <> "\n"
  <> type_alias_equals(db, "structure." <> db)
  <> "\n"
  <> type_alias_equals(filterable, "structure." <> filterable)
  <> "\n"
  <> type_alias_equals("StringRefOrValue", "structure.StringRefOrValue")
  <> "\n"
  <> type_alias_equals("NumRefOrValue", "structure.NumRefOrValue")
  <> "\n"
  <> type_alias_equals(num_ref, "structure." <> num_ref)
  <> "\n"
  <> type_alias_equals(str_ref, "structure." <> str_ref)
  <> "\n"
  <> type_alias_equals(field_enum, "structure." <> field_enum)
  <> "\n"
  <> "pub fn "
  <> singular
  <> "("
  <> resource_fields
  <> ") -> "
  <> t
  <> " {\n"
  <> "  "
  <> ctx.variant_name
  <> "("
  <> join_label_shorthands(ctx.fields)
  <> ")\n"
  <> "}\n"
  <> "\n"
  <> "pub fn "
  <> singular
  <> "_with_"
  <> identity_suffix(ctx)
  <> "("
  <> upsert_identity_params_signature(ctx)
  <> upsert_rest_params_suffix(ctx)
  <> ") -> "
  <> upsert
  <> " {\n"
  <> "  resource."
  <> singular
  <> "_with_"
  <> identity_suffix(ctx)
  <> "("
  <> resource_with_helper_args(ctx)
  <> ")\n"
  <> "}\n"
  <> "\n"
  <> "pub fn "
  <> table_fn
  <> "(conn: sqlight.Connection) -> "
  <> db
  <> " {\n"
  <> "  crud."
  <> table_fn
  <> "(conn)\n"
  <> "}\n"
  <> "\n"
  <> "pub fn migrate_idempotent(\n"
  <> "  conn: sqlight.Connection,\n"
  <> ") -> Result(Nil, sqlight.Error) {\n"
  <> "  migrate.migrate_idempotent(conn)\n"
  <> "}\n"
}

fn type_alias_equals(name: String, rhs: String) -> String {
  "pub type " <> name <> " =\n  " <> rhs <> "\n"
}

fn join_label_shorthands(fields: List(#(String, a))) -> String {
  case fields {
    [] -> ""
    [#(l, _), ..rest] ->
      l
      <> ":"
      <> case rest {
        [] -> ""
        _ -> ", " <> join_label_shorthands(rest)
      }
  }
}

fn identity_suffix(ctx: SchemaContext) -> String {
  string.join(ctx.identity_labels, "_")
}

fn upsert_identity_params_signature(ctx: SchemaContext) -> String {
  list.map(ctx.identity_labels, fn(label) {
    let assert Ok(#(_, typ)) =
      list.find(ctx.fields, fn(pair) { pair.0 == label })
    label <> ": " <> sql_types.identity_upsert_param_type(typ)
  })
  |> string.join(", ")
}

fn upsert_rest_params_suffix(ctx: SchemaContext) -> String {
  let ids = ctx.identity_labels
  ctx.fields
  |> list.filter(fn(pair) { !list.contains(ids, pair.0) })
  |> list.map(fn(pair) {
    let #(label, typ) = pair
    ", " <> label <> ": " <> sql_types.rendered_type(typ)
  })
  |> string.concat
}

/// Arguments to `resource.<singular>_with_*` follow schema field order (matches generated resource fn).
fn resource_with_helper_args(ctx: SchemaContext) -> String {
  ctx.fields
  |> list.map(fn(pair) { pair.0 })
  |> string.join(", ")
}
