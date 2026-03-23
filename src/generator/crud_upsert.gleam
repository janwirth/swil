import gleam/list
import gleam/string

import generator/schema_context.{type SchemaContext}
import generator/sqlight_param

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let upsert = ctx.for_upsert_type_name
  let uv = ctx.for_upsert_variant_name
  let row = ctx.row_name
  let table = ctx.table
  let singular = ctx.singular
  let insert_cols = insert_columns_list(ctx)
  let placeholders = insert_values_placeholders(ctx)
  let conflict = string.join(ctx.identity_labels, ", ")
  let update_excluded = upsert_update_excluded(ctx)
  let pattern = upsert_pattern(ctx)
  let with_lines = upsert_with_values(ctx)
  let select_where =
    ctx.identity_labels
    |> list.map(fn(l) { l <> " = ?" })
    |> string.join(" and ")
  let select_with_bindings = upsert_select_with_bindings(ctx)
  let decoder = ctx.singular <> "_row_decoder"
  "import gleam/dynamic/decode\n"
  <> "import gleam/list\n"
  <> "import gleam/option\n"
  <> "import gleam/result\n"
  <> "import sqlight\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/resource.{type "
  <> upsert
  <> ", "
  <> uv
  <> "}\n"
  <> "import "
  <> layer
  <> "/structure.{type "
  <> row
  <> ", "
  <> decoder
  <> "}\n"
  <> "\n"
  <> "pub fn upsert_one(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  "
  <> singular
  <> ": "
  <> upsert
  <> ",\n"
  <> ") -> Result("
  <> row
  <> ", sqlight.Error) {\n"
  <> "  let stamp = 1\n"
  <> "  case "
  <> singular
  <> " {\n"
  <> "    "
  <> pattern
  <> " -> {\n"
  <> "      let upsert =\n"
  <> "        \"insert into "
  <> table
  <> " ("
  <> insert_cols
  <> ") values ("
  <> placeholders
  <> ") on conflict("
  <> conflict
  <> ") do update set "
  <> update_excluded
  <> "\"\n"
  <> "      use _ <- result.try(sqlight.query(\n"
  <> "        upsert,\n"
  <> "        on: conn,\n"
  <> "        with: [\n"
  <> with_lines
  <> "        ],\n"
  <> "        expecting: decode.success(Nil),\n"
  <> "      ))\n"
  <> "      sqlight.query(\n"
  <> "        \"select id, created_at, updated_at, deleted_at, "
  <> list.map(ctx.fields, fn(p) { p.0 }) |> string.join(", ")
  <> " from "
  <> table
  <> " where "
  <> select_where
  <> " and deleted_at is null limit 1\",\n"
  <> "        on: conn,\n"
  <> "        with: [\n"
  <> select_with_bindings
  <> "        ],\n"
  <> "        expecting: "
  <> decoder
  <> "(),\n"
  <> "      )\n"
  <> "      |> result.map(fn(rows) {\n"
  <> "        let assert [r] = rows\n"
  <> "        r\n"
  <> "      })\n"
  <> "    }\n"
  <> "  }\n"
  <> "}\n"
  <> "\n"
  <> "pub fn upsert_many(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  rows: List("
  <> upsert
  <> "),\n"
  <> ") -> Result(List("
  <> row
  <> "), sqlight.Error) {\n"
  <> "  list.try_map(over: rows, with: fn(c) { upsert_one(conn, c) })\n"
  <> "}\n"
}

fn insert_columns_list(ctx: SchemaContext) -> String {
  let fs =
    list.map(ctx.fields, fn(pair) { pair.0 })
    |> string.join(", ")
  fs <> ", created_at, updated_at, deleted_at"
}

fn insert_values_placeholders(ctx: SchemaContext) -> String {
  let n = list.length(ctx.fields) + 2
  list.repeat("?", n)
  |> string.join(", ")
  <> ", null"
}

fn upsert_update_excluded(ctx: SchemaContext) -> String {
  let ids = ctx.identity_labels
  let parts =
    ctx.fields
    |> list.filter(fn(pair) { !list.contains(ids, pair.0) })
    |> list.map(fn(pair) { pair.0 <> " = excluded." <> pair.0 })
  let with_ts =
    list.append(parts, ["updated_at = excluded.updated_at", "deleted_at = null"])
  string.join(with_ts, ", ")
}

fn upsert_pattern(ctx: SchemaContext) -> String {
  let ids = ctx.identity_labels
  let inner =
    list.map(ctx.fields, fn(pair) {
      let #(label, _) = pair
      case list.contains(ids, label) {
        True -> label <> ": " <> label
        False -> label <> ":"
      }
    })
    |> string.join(", ")
  ctx.for_upsert_variant_name <> "(" <> inner <> ")"
}

fn upsert_with_values(ctx: SchemaContext) -> String {
  let ids = ctx.identity_labels
  let lines =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      let expr = case list.contains(ids, label) {
        True -> sqlight_param.from_identity_case_column(label, typ)
        False -> sqlight_param.from_pattern_field(label, typ)
      }
      "          " <> expr <> ",\n"
    })
    |> string.concat
  lines
  <> "          sqlight.int(stamp),\n"
  <> "          sqlight.int(stamp),\n"
}

fn upsert_select_with_bindings(ctx: SchemaContext) -> String {
  list.map(ctx.identity_labels, fn(label) {
    let assert Ok(#(_, typ)) =
      list.find(ctx.fields, fn(p) { p.0 == label })
    "          " <> sqlight_param.from_identity_lookup_param(label, typ) <> ",\n"
  })
  |> string.concat
}
