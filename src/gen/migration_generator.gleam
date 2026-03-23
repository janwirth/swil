import glance
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string
import gleamgen/render as gleamgen_render
import gleamgen/types as gleamgen_types

pub fn generate(module: String, version: String) -> String {
  let assert Ok(parsed) = glance.module(module)
  let assert [glance.Definition(_, custom_type), ..] = parsed.custom_types
  let columns = extract_columns(custom_type.variants)
  let has_tail_expression = version == "idemptotent"
  let column_lines = render_column_lines(columns, has_tail_expression)
  let identity_lines = case version == "idemptotent" {
    True ->
      "\n"
      <> "  sqlight.exec(\n"
      <> "    \"create unique index if not exists cats_identity_name_idx on cats (name);\",\n"
      <> "    conn,\n"
      <> "  )\n"
    False -> "\n"
  }
  let migrate_v2 = case version == "idemptotent" {
    True ->
      "\n"
      <> "pub fn migrate_v2(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {\n"
      <> "  migrate_idemptotent(conn)\n"
      <> "}\n"
    False -> ""
  }

  "import gleam/result\n"
  <> "\n"
  <> "import gen/migration_help as shared\n"
  <> "import sqlight\n"
  <> "\n"
  <> "pub fn migrate_"
  <> version
  <> "(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {\n"
  <> "  use _ <- result.try(shared.ensure_base_table(conn))\n"
  <> column_lines
  <> identity_lines
  <> "}\n"
  <> migrate_v2
}

fn extract_columns(variants: List(glance.Variant)) -> List(#(String, glance.Type)) {
  case variants {
    [glance.Variant(_, fields, _), ..] -> extract_fields(fields, 1, [])
    [] -> []
  }
}

fn extract_fields(
  fields: List(glance.VariantField),
  index: Int,
  acc: List(#(String, glance.Type)),
) -> List(#(String, glance.Type)) {
  case fields {
    [field, ..rest] -> {
      let pair = case field {
        glance.LabelledVariantField(item, label) -> #(label, item)
        glance.UnlabelledVariantField(item) ->
          #("field_" <> int.to_string(index), item)
      }
      extract_fields(rest, index + 1, [pair, ..acc])
    }
    [] -> list.reverse(acc)
  }
}

fn render_column_lines(
  columns: List(#(String, glance.Type)),
  has_tail_expression: Bool,
) -> String {
  let field_count = list.length(columns)
  build_column_lines(columns, 0, field_count, has_tail_expression, [])
  |> list.reverse
  |> string.join("\n")
}

fn build_column_lines(
  columns: List(#(String, glance.Type)),
  index: Int,
  field_count: Int,
  has_tail_expression: Bool,
  acc: List(String),
) -> List(String) {
  case columns {
    [#(name, type_), ..rest] -> {
      let sql = "alter table cats add column " <> name <> " " <> sql_type(type_) <> ";"
      let call = "shared.ensure_column(conn, \"" <> name <> "\", \"" <> sql <> "\")"
      let is_last = index == field_count - 1
      let line = case is_last && !has_tail_expression {
        True -> "  " <> call
        False -> "  use _ <- result.try(" <> call <> ")"
      }
      build_column_lines(rest, index + 1, field_count, has_tail_expression, [line, ..acc])
    }
    [] -> acc
  }
}

fn to_generated_type(type_: glance.Type) -> gleamgen_types.GeneratedType(
  gleamgen_types.Unchecked,
) {
  case type_ {
    glance.NamedType(_, "String", None, []) ->
      gleamgen_types.string |> gleamgen_types.to_unchecked
    glance.NamedType(_, "Int", None, []) ->
      gleamgen_types.int |> gleamgen_types.to_unchecked
    glance.NamedType(_, "Float", None, []) ->
      gleamgen_types.float |> gleamgen_types.to_unchecked
    glance.NamedType(_, "Bool", None, []) ->
      gleamgen_types.bool |> gleamgen_types.to_unchecked
    glance.NamedType(_, "Nil", None, []) ->
      gleamgen_types.nil |> gleamgen_types.to_unchecked
    glance.NamedType(_, name, module, params) ->
      gleamgen_types.custom_type(module, name, list.map(params, to_generated_type))
    glance.TupleType(_, elements) ->
      gleamgen_types.custom_type(None, "Tuple", list.map(elements, to_generated_type))
    glance.FunctionType(_, _, _) -> gleamgen_types.unchecked()
    glance.VariableType(_, name) -> gleamgen_types.unchecked_ident(name)
    glance.HoleType(_, _) -> gleamgen_types.unchecked()
  }
}

fn rendered_type(type_: glance.Type) -> String {
  case to_generated_type(type_) |> gleamgen_types.render_type {
    Ok(rendered) -> gleamgen_render.to_string(rendered)
    Error(_) -> "Unknown"
  }
}

fn sql_type(type_: glance.Type) -> String {
  case rendered_type(type_) {
    "Int" -> "int"
    "Float" -> "real"
    "Bool" -> "int"
    "String" -> "text"
    rendered ->
      case string.starts_with(rendered, "Option(") {
        False -> "text"
        True ->
          case rendered {
            "Option(Int)" -> "int"
            "Option(Float)" -> "real"
            "Option(Bool)" -> "int"
            _ -> "text"
          }
      }
  }
}
