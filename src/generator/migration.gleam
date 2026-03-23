import glance
import gleam/list
import gleam/option.{Some}
import gleam/string

import generator/schema_context
import generator/sql_types
import gleamgen/render as gleamgen_render
import gleamgen/types as gleamgen_types

pub fn generate(module: String) -> String {
  let assert Ok(ctx) = schema_context.migration_context(module)
  generate_migration(ctx, ctx.table)
}

fn flatten_rendered_type(s: String) -> String {
  string.replace(s, "\n", "")
}

fn generate_migration(
  ctx: schema_context.MigrationContext,
  module_name: String,
) -> String {
  let has_tail_after_columns = case ctx.identity_labels {
    [] -> False
    _ -> True
  }
  let column_lines =
    render_column_lines(ctx.columns, module_name, has_tail_after_columns)
  let identity_lines = render_identity_indexes(module_name, ctx.identity_labels)
  let assert Ok(return_rendered) =
    gleamgen_types.render_type(
      gleamgen_types.result(
        gleamgen_types.nil,
        gleamgen_types.custom_type(Some("sqlight"), "Error", []),
      ),
    )
  let return_type = flatten_rendered_type(gleamgen_render.to_string(return_rendered))
  let assert Ok(conn_rendered) =
    gleamgen_types.render_type(
      gleamgen_types.custom_type(Some("sqlight"), "Connection", []),
    )
  let conn_type = flatten_rendered_type(gleamgen_render.to_string(conn_rendered))
  "import gleam/result\n"
  <> "\n"
  <> "import help/migrate as migration_help\n"
  <> "import sqlight\n"
  <> "\n"
  <> "pub fn migrate_idempotent(conn: "
  <> conn_type
  <> ") -> "
  <> return_type
  <> " {\n"
  <> "  use _ <- result.try(migration_help.ensure_base_table(conn))\n"
  <> column_lines
  <> identity_lines
  <> "}\n"
}

fn render_identity_indexes(module_name: String, labels: List(String)) -> String {
  case labels {
    [] -> "\n"
    [one] -> {
      let idx = module_name <> "_identity_" <> one <> "_idx"
      "\n"
      <> "  sqlight.exec(\n"
      <> "    \"create unique index if not exists "
      <> idx
      <> " on "
      <> module_name
      <> " ("
      <> one
      <> ");\",\n"
      <> "    conn,\n"
      <> "  )\n"
    }
    many -> {
      let cols = string.join(many, ", ")
      let idx = module_name <> "_identity_idx"
      "\n"
      <> "  sqlight.exec(\n"
      <> "    \"create unique index if not exists "
      <> idx
      <> " on "
      <> module_name
      <> " ("
      <> cols
      <> ");\",\n"
      <> "    conn,\n"
      <> "  )\n"
    }
  }
}

fn render_column_lines(
  columns: List(#(String, glance.Type)),
  module_name: String,
  has_tail_expression: Bool,
) -> String {
  let field_count = list.length(columns)
  build_column_lines(
    columns,
    module_name,
    0,
    field_count,
    has_tail_expression,
    [],
  )
  |> list.reverse
  |> string.join("\n")
}

fn build_column_lines(
  columns: List(#(String, glance.Type)),
  module_name: String,
  index: Int,
  field_count: Int,
  has_tail_expression: Bool,
  acc: List(String),
) -> List(String) {
  case columns {
    [#(name, type_), ..rest] -> {
      let sql =
        "alter table "
        <> module_name
        <> " add column "
        <> name
        <> " "
        <> sql_types.sql_type(type_)
        <> ";"
      let call =
        "migration_help.ensure_column(conn, \"" <> name <> "\", \"" <> sql <> "\")"
      let is_last = index == field_count - 1
      let line = case is_last && !has_tail_expression {
        True -> "  " <> call
        False -> "  use _ <- result.try(" <> call <> ")"
      }
      build_column_lines(
        rest,
        module_name,
        index + 1,
        field_count,
        has_tail_expression,
        [line, ..acc],
      )
    }
    [] -> acc
  }
}
