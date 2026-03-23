import glance
import gleam/list
import gleam/string

import generator/schema_context
import generator/sql_types

pub fn generate(module: String, version: String) -> String {
  let assert Ok(ctx) = schema_context.migration_context(module)
  generate_migration(ctx, version)
}

fn generate_migration(ctx: schema_context.MigrationContext, version: String) -> String {
  let has_tail_expression = version == "idemptotent"
  let column_lines = render_column_lines(ctx.columns, ctx.table, has_tail_expression)
  let identity_lines = case version == "idemptotent" {
    True -> render_identity_indexes(ctx.table, ctx.identity_labels)
    False -> "\n"
  }
  "import gleam/result\n"
  <> "\n"
  <> "import help/migrate as migration_help\n"
  <> "import sqlight\n"
  <> "\n"
  <> "pub fn migrate_idemptotent(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {\n"
  <> "  use _ <- result.try(migration_help.ensure_base_table(conn))\n"
  <> column_lines
  <> identity_lines
  <> "}\n"
}

fn render_identity_indexes(table: String, labels: List(String)) -> String {
  case labels {
    [] -> "\n"
    _ -> {
      let lines =
        list.map(labels, fn(label) {
          let idx = table <> "_identity_" <> label <> "_idx"
          "\n"
          <> "  sqlight.exec(\n"
          <> "    \"create unique index if not exists "
          <> idx
          <> " on "
          <> table
          <> " ("
          <> label
          <> ");\",\n"
          <> "    conn,\n"
          <> "  )\n"
        })
      string.join(lines, "")
    }
  }
}

fn render_column_lines(
  columns: List(#(String, glance.Type)),
  table: String,
  has_tail_expression: Bool,
) -> String {
  let field_count = list.length(columns)
  build_column_lines(columns, table, 0, field_count, has_tail_expression, [])
  |> list.reverse
  |> string.join("\n")
}

fn build_column_lines(
  columns: List(#(String, glance.Type)),
  table: String,
  index: Int,
  field_count: Int,
  has_tail_expression: Bool,
  acc: List(String),
) -> List(String) {
  case columns {
    [#(name, type_), ..rest] -> {
      let sql =
        "alter table "
        <> table
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
      build_column_lines(rest, table, index + 1, field_count, has_tail_expression, [
        line,
        ..acc
      ])
    }
    [] -> acc
  }
}
