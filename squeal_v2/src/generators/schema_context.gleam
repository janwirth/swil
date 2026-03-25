import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type SchemaContext {
  SchemaContext(
    layer: String,
    /// Gleam module that defines the schema type (e.g. `cat_schema` for `src/cat_schema.gleam`).
    schema_module: String,
    table: String,
    type_name: String,
    variant_name: String,
    fields: List(#(String, glance.Type)),
    identity_labels: List(String),
    singular: String,
    plural_type: String,
    filterable_name: String,
    row_name: String,
    db_type_name: String,
    field_enum_name: String,
    num_field_enum_name: String,
    string_field_enum_name: String,
    for_upsert_type_name: String,
    for_upsert_variant_name: String,
  )
}

/// `src/cat_schema.gleam` → `cat_schema`; `src/foo/bar.gleam` → `foo/bar`.
pub fn schema_module_from_src_path(path: String) -> String {
  let rel = case string.split(path, "src/") {
    [_, rest] -> rest
    _ -> path
  }
  case string.split(rel, ".gleam") {
    [base, ..] -> base
    _ -> rel
  }
}

pub type MigrationContext {
  MigrationContext(
    table: String,
    columns: List(#(String, glance.Type)),
    identity_labels: List(String),
  )
}

pub fn migration_context(module_source: String) -> Result(MigrationContext, Nil) {
  use parsed <- result.try(result.replace_error(
    glance.module(module_source),
    Nil,
  ))
  case parse_with_parsed(module_source, parsed, "") {
    Ok(ctx) ->
      Ok(MigrationContext(
        table: ctx.table,
        columns: ctx.fields,
        identity_labels: ctx.identity_labels,
      ))
    Error(_) -> migration_context_minimal(parsed)
  }
}

fn migration_context_minimal(
  parsed: glance.Module,
) -> Result(MigrationContext, Nil) {
  case parsed.custom_types {
    [glance.Definition(_, ct), ..] ->
      case ct.variants {
        [glance.Variant(_, vfields, _), ..] -> {
          let fields = extract_variant_fields(vfields, 1, [])
          let table = decapitalize(ct.name) <> "s"
          Ok(
            MigrationContext(
              table: table,
              columns: list.reverse(fields),
              identity_labels: [],
            ),
          )
        }
        [] -> Error(Nil)
      }
    [] -> Error(Nil)
  }
}

pub fn parse(
  module_source: String,
  schema_module: String,
) -> Result(SchemaContext, Nil) {
  use parsed <- result.try(result.replace_error(
    glance.module(module_source),
    Nil,
  ))
  parse_with_parsed(module_source, parsed, schema_module)
}

fn parse_with_parsed(
  _module_source: String,
  parsed: glance.Module,
  schema_module: String,
) -> Result(SchemaContext, Nil) {
  use #(type_name, variant_name, fields) <- result.try(extract_schema_type(
    parsed.custom_types,
  ))
  let layer = default_layer_module(type_name)
  let table = resolve_table_alias(parsed.imports, layer, type_name)
  let identity_labels = extract_identity_labels(parsed.functions)
  use _ <- result.try(case identity_labels {
    [] -> Error(Nil)
    _ -> Ok(Nil)
  })
  let singular = decapitalize(type_name)
  let plural_type = type_name <> "s"
  let filterable_name = "Filterable" <> type_name
  let row_name = type_name <> "Row"
  let db_type_name = plural_type <> "Db"
  let field_enum_name = type_name <> "Field"
  let num_field_enum_name = "Num" <> type_name <> "Field"
  let string_field_enum_name = "String" <> type_name <> "Field"
  let for_upsert_type_name = type_name <> "ForUpsert"
  let for_upsert_variant_name =
    type_name
    <> "With"
    <> string.concat(list.map(identity_labels, pascal_case_field_label))
  Ok(SchemaContext(
    layer: layer,
    schema_module: schema_module,
    table: table,
    type_name: type_name,
    variant_name: variant_name,
    fields: fields,
    identity_labels: identity_labels,
    singular: singular,
    plural_type: plural_type,
    filterable_name: filterable_name,
    row_name: row_name,
    db_type_name: db_type_name,
    field_enum_name: field_enum_name,
    num_field_enum_name: num_field_enum_name,
    string_field_enum_name: string_field_enum_name,
    for_upsert_type_name: for_upsert_type_name,
    for_upsert_variant_name: for_upsert_variant_name,
  ))
}

fn default_layer_module(type_name: String) -> String {
  decapitalize(type_name) <> "_db"
}

fn find_entry_alias(
  imports: List(glance.Definition(glance.Import)),
  layer: String,
) -> Result(String, Nil) {
  let expected = layer <> "/entry"
  find_entry_alias_loop(imports, expected)
}

fn find_entry_alias_loop(
  imports: List(glance.Definition(glance.Import)),
  expected: String,
) -> Result(String, Nil) {
  case imports {
    [] -> Error(Nil)
    [glance.Definition(_, imp), ..rest] ->
      case imp.module == expected {
        True ->
          case imp.alias {
            Some(glance.Named(name)) -> Ok(name)
            _ -> Error(Nil)
          }
        False -> find_entry_alias_loop(rest, expected)
      }
  }
}

/// Table accessor name: `import <layer>/entry as cats` if present, else `cats` / `dogs` from the schema type.
fn resolve_table_alias(
  imports: List(glance.Definition(glance.Import)),
  layer: String,
  type_name: String,
) -> String {
  case find_entry_alias(imports, layer) {
    Ok(alias) -> alias
    Error(_) -> decapitalize(type_name) <> "s"
  }
}

fn extract_schema_type(
  custom_types: List(glance.Definition(glance.CustomType)),
) -> Result(#(String, String, List(#(String, glance.Type))), Nil) {
  case custom_types {
    [glance.Definition(_, ct), ..] -> {
      case ct.variants {
        [glance.Variant(vname, vfields, _), ..] -> {
          let fields = extract_variant_fields(vfields, 1, [])
          Ok(#(ct.name, vname, list.reverse(fields)))
        }
        [] -> Error(Nil)
      }
    }
    [] -> Error(Nil)
  }
}

fn extract_variant_fields(
  fields: List(glance.VariantField),
  index: Int,
  acc: List(#(String, glance.Type)),
) -> List(#(String, glance.Type)) {
  case fields {
    [field, ..rest] -> {
      let pair = case field {
        glance.LabelledVariantField(item, label) -> #(label, item)
        glance.UnlabelledVariantField(item) -> #(
          "field_" <> int.to_string(index),
          item,
        )
      }
      extract_variant_fields(rest, index + 1, [pair, ..acc])
    }
    [] -> acc
  }
}

fn extract_identity_labels(
  functions: List(glance.Definition(glance.Function)),
) -> List(String) {
  case find_identities_function(functions) {
    Some(fn_def) -> identity_labels_from_body(fn_def.body)
    None -> []
  }
}

fn find_identities_function(
  functions: List(glance.Definition(glance.Function)),
) -> Option(glance.Function) {
  case functions {
    [] -> None
    [glance.Definition(_, f), ..rest] ->
      case f.name == "identities" {
        True -> Some(f)
        False -> find_identities_function(rest)
      }
  }
}

fn identity_labels_from_body(body: List(glance.Statement)) -> List(String) {
  case body {
    [stmt, ..] -> statements_identity_labels([stmt])
    [] -> []
  }
}

fn statements_identity_labels(stmts: List(glance.Statement)) -> List(String) {
  case stmts {
    [] -> []
    [stmt, ..rest] -> {
      let from_stmt = case stmt {
        glance.Expression(e) -> expression_identity_labels(e)
        _ -> []
      }
      list.append(from_stmt, statements_identity_labels(rest))
    }
  }
}

fn expression_identity_labels(expr: glance.Expression) -> List(String) {
  case expr {
    glance.List(_, elements, None) ->
      list.flat_map(elements, identity_labels_from_identity_call)
    glance.Block(_, inner) ->
      list.flat_map(inner, fn(s) {
        case s {
          glance.Expression(e) -> expression_identity_labels(e)
          _ -> []
        }
      })
    _ -> []
  }
}

/// Reads `identity.Identity(x.f)`, `Identity2(a.b, a.c)`, etc. (constructor name from AST).
fn identity_labels_from_identity_call(expr: glance.Expression) -> List(String) {
  case expr {
    glance.Call(_, fun, args) ->
      case field_access_last(fun) {
        Some("Identity") -> labels_from_call_args(args, 1)
        Some("Identity2") -> labels_from_call_args(args, 2)
        Some("Identity3") -> labels_from_call_args(args, 3)
        _ -> []
      }
    _ -> []
  }
}

fn labels_from_call_args(
  args: List(glance.Field(glance.Expression)),
  want: Int,
) -> List(String) {
  let got = list.take(args, want)
  case list.length(got) == want {
    False -> []
    True ->
      list.filter_map(got, fn(arg) {
        case arg {
          glance.UnlabelledField(inner) ->
            case field_access_last(inner) {
              Some(s) -> Ok(s)
              None -> Error(Nil)
            }
          glance.LabelledField(_, _, inner) ->
            case field_access_last(inner) {
              Some(s) -> Ok(s)
              None -> Error(Nil)
            }
          glance.ShorthandField(label, _) -> Ok(label)
        }
      })
  }
}

fn field_access_last(expr: glance.Expression) -> Option(String) {
  case expr {
    glance.FieldAccess(_, inner, label) ->
      case inner {
        glance.FieldAccess(_, _, _) ->
          case field_access_last(inner) {
            None -> Some(label)
            Some(_) -> Some(label)
          }
        _ -> Some(label)
      }
    _ -> None
  }
}

pub fn decapitalize(s: String) -> String {
  case string.pop_grapheme(s) {
    Ok(#(g, rest)) -> string.lowercase(g) <> rest
    Error(Nil) -> s
  }
}

pub fn capitalize(s: String) -> String {
  case string.pop_grapheme(s) {
    Ok(#(g, rest)) -> string.uppercase(g) <> rest
    Error(Nil) -> s
  }
}

fn segment_to_title_case(segment: String) -> String {
  case string.pop_grapheme(segment) {
    Ok(#(g, rest)) -> string.uppercase(g) <> rest
    Error(Nil) -> segment
  }
}

/// `is_neutered` → `IsNeutered` for valid Gleam variant names.
pub fn pascal_case_field_label(label: String) -> String {
  string.split(label, "_")
  |> list.map(segment_to_title_case)
  |> string.concat
}
