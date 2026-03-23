import gleam/list
import gleam/string

import generator/schema_context.{type SchemaContext}
import generator/sql_types

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
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
    <> "` / `migrate_idemptotent`, and `"
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
    <> "\n"
    <> "pub type "
    <> t
    <> " = resource."
    <> t
    <> "\n"
    <> "\n"
    <> "pub type "
    <> upsert
    <> " = resource."
    <> upsert
    <> "\n"
    <> "\n"
    <> "pub type "
    <> row
    <> " = structure."
    <> row
    <> "\n"
    <> "\n"
    <> "pub type "
    <> db
    <> " = structure."
    <> db
    <> "\n"
    <> "\n"
    <> "pub type "
    <> filterable
    <> " = structure."
    <> filterable
    <> "\n"
    <> "\n"
    <> "pub type StringRefOrValue = structure.StringRefOrValue\n"
    <> "\n"
    <> "pub type NumRefOrValue = structure.NumRefOrValue\n"
    <> "\n"
    <> "pub type "
    <> num_ref
    <> " = structure."
    <> num_ref
    <> "\n"
    <> "\n"
    <> "pub type "
    <> str_ref
    <> " = structure."
    <> str_ref
    <> "\n"
    <> "\n"
    <> "pub type "
    <> field_enum
    <> " = structure."
    <> field_enum
    <> "\n"
    <> "\n"
    <> "pub fn "
    <> singular
    <> "("
    <> resource_fields
    <> ") -> "
    <> t
    <> " {\n"
    <> "  resource."
    <> ctx.variant_name
    <> "("
    <> join_labels(ctx.fields)
    <> ")\n"
    <> "}\n"
    <> "\n"
    <> "pub fn "
    <> singular
    <> "_with_"
    <> first_identity(ctx)
    <> "("
    <> first_identity(ctx)
    <> ": String"
    <> upsert_rest_params_suffix(ctx)
    <> ") -> "
    <> upsert
    <> " {\n"
    <> "  resource."
    <> singular
    <> "_with_"
    <> first_identity(ctx)
    <> "("
    <> first_identity(ctx)
    <> ", "
    <> upsert_rest_args(ctx)
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
    <> "pub fn migrate_idemptotent(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {\n"
    <> "  migrate.migrate_idemptotent(conn)\n"
    <> "}\n"
}

fn join_labels(fields: List(#(String, a))) -> String {
  case fields {
    [] -> ""
    [#(l, _), ..rest] ->
      l
      <> case rest {
        [] -> ""
        _ -> ", " <> join_labels(rest)
      }
  }
}

fn first_identity(ctx: SchemaContext) -> String {
  case ctx.identity_labels {
    [l, ..] -> l
    [] -> ""
  }
}

fn upsert_rest_params_suffix(ctx: SchemaContext) -> String {
  case ctx.identity_labels {
    [] -> ""
    [primary, ..] -> {
      let rest =
        ctx.fields
        |> list.filter(fn(pair) { pair.0 != primary })
        |> list.map(fn(pair) {
          let #(label, typ) = pair
          ", " <> label <> ": " <> sql_types.rendered_type(typ)
        })
        |> string.concat
      rest
    }
  }
}

fn upsert_rest_args(ctx: SchemaContext) -> String {
  case ctx.identity_labels {
    [] -> join_labels(ctx.fields)
    [primary, ..] -> {
      let rest =
        ctx.fields
        |> list.filter(fn(pair) { pair.0 != primary })
        |> list.map(fn(pair) { pair.0 })
        |> string.join(", ")
      case rest {
        "" -> primary
        _ -> primary <> ", " <> rest
      }
    }
  }
}
