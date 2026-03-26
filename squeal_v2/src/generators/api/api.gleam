import generators/api/api_sql
import generators/gleamgen_emit
import generators/sql_types
import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/import_ as gimport
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/render as grender
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition, type IdentityTypeDefinition,
  type IdentityVariantDefinition, type SchemaDefinition,
}

/// Renders a sqlight API module (constants, helpers, CRUD, generated query SQL).
pub fn generate_api(
  schema_import_path: String,
  schema: SchemaDefinition,
) -> String {
  build_module(schema_import_path, schema)
  |> gmod.render(grender.default_context())
  |> grender.to_string()
  |> finalize_string
}

fn finalize_string(s: String) -> String {
  case string.ends_with(s, "\n") {
    True -> s
    False -> s <> "\n"
  }
}

fn migration_import_path(schema_path: String) -> String {
  case string.split(schema_path, "/") {
    [] -> schema_path
    parts -> {
      let assert Ok(last) = list.last(parts)
      let n = list.length(parts)
      let prefix = list.take(parts, n - 1)
      let base = string.replace(last, "_schema", "")
      list.append(prefix, [base <> "_db", "migration"])
      |> string.join("/")
    }
  }
}

fn glance_type_referenced_names(t: glance.Type) -> List(String) {
  case t {
    glance.NamedType(_, name, _, params) ->
      list.append(
        [name],
        params
        |> list.map(glance_type_referenced_names)
        |> list.flatten,
      )
    glance.TupleType(_, els) ->
      els
      |> list.map(glance_type_referenced_names)
      |> list.flatten
    _ -> []
  }
}

fn uniq_sorted_strings(xs: List(String)) -> List(String) {
  list.sort(xs, string.compare)
  |> list.reverse
  |> list.fold([], fn(acc, x) {
    case acc {
      [y, ..] if x == y -> acc
      _ -> [x, ..acc]
    }
  })
  |> list.reverse
}

fn entity_used_scalar_type_names(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> List(String) {
  let scalar_type_names = list.map(def.scalars, fn(s) { s.type_name })
  let id = find_identity(def, entity)
  let from_fields =
    entity.fields
    |> list.filter(fn(f) {
      f.label != "identities" && f.label != "relationships"
    })
    |> list.flat_map(fn(f) { glance_type_referenced_names(f.type_) })
  let from_id =
    id.variants
    |> list.flat_map(fn(v) {
      v.fields
      |> list.flat_map(fn(f) { glance_type_referenced_names(f.type_) })
    })
  list.filter(list.append(from_fields, from_id), fn(n) {
    list.contains(scalar_type_names, n)
  })
  |> uniq_sorted_strings
}

fn entity_relationship_container_names(entity: EntityDefinition) -> List(String) {
  case list.find(entity.fields, fn(f) { f.label == "relationships" }) {
    Error(_) -> []
    Ok(f) ->
      case f.type_ {
        glance.NamedType(_, n, None, []) -> [n]
        glance.NamedType(_, n, Some(_), []) -> [n]
        _ -> []
      }
  }
}

/// Exposing list for a single-entity API module (first entity only): its types, referenced scalars,
/// identity variants — not other entities in the schema.
fn api_schema_exposing(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> String {
  let id = find_identity(def, entity)
  let scalar_names = entity_used_scalar_type_names(def, entity)
  let rel_names =
    entity_relationship_container_names(entity)
    |> list.sort(string.compare)
  let type_exports =
    list.flatten([
      list.map(scalar_names, fn(s) { "type " <> s }),
      ["type " <> entity.type_name],
      list.map(rel_names, fn(r) { "type " <> r }),
    ])
    |> list.sort(string.compare)
  let scalar_variants =
    def.scalars
    |> list.filter(fn(s) { list.contains(scalar_names, s.type_name) })
    |> list.flat_map(fn(s) { s.variant_names })
  let id_variant_names = list.map(id.variants, fn(v) { v.variant_name })
  let value_exports =
    list.flatten([
      id_variant_names,
      scalar_variants,
      [entity.type_name, ..rel_names],
    ])
    |> list.sort(string.compare)
  string.join(list.append(type_exports, value_exports), ", ")
}

fn import_alias(path: String) -> String {
  case string.split(path, "/") |> list.reverse() {
    [a, ..] -> a
    [] -> path
  }
}

type TypeCtx {
  TypeCtx(
    schema_alias: String,
    entity_names: List(String),
    scalar_names: List(String),
  )
}

fn type_ctx(schema_path: String, def: SchemaDefinition) -> TypeCtx {
  TypeCtx(
    schema_alias: import_alias(schema_path),
    entity_names: list.map(def.entities, fn(e) { e.type_name }),
    scalar_names: list.map(def.scalars, fn(s) { s.type_name }),
  )
}

fn render_type(t: glance.Type, ctx: TypeCtx) -> String {
  case t {
    glance.NamedType(_, "MagicFields", _, []) -> "dsl.MagicFields"
    glance.NamedType(_, "String", None, []) -> "String"
    glance.NamedType(_, "Int", None, []) -> "Int"
    glance.NamedType(_, "Float", None, []) -> "Float"
    glance.NamedType(_, "Bool", None, []) -> "Bool"
    glance.NamedType(_, "Date", _, []) -> "Date"
    glance.NamedType(_, "Timestamp", _, []) -> "Timestamp"
    glance.NamedType(_, "Option", _, [inner]) ->
      "Option(" <> render_type(inner, ctx) <> ")"
    glance.NamedType(_, "List", _, [inner]) ->
      "List(" <> render_type(inner, ctx) <> ")"
    glance.NamedType(_, name, None, []) ->
      case list.contains(ctx.scalar_names, name) {
        True -> name
        False -> name
      }
    glance.NamedType(_, name, Some(_), []) ->
      case list.contains(ctx.scalar_names, name) {
        True -> name
        False -> name
      }
    glance.NamedType(_, name, _, params) ->
      name
      <> "("
      <> string.join(list.map(params, fn(p) { render_type(p, ctx) }), ", ")
      <> ")"
    glance.TupleType(_, els) ->
      "#("
      <> string.join(list.map(els, fn(e) { render_type(e, ctx) }), ", ")
      <> ")"
    glance.FunctionType(_, _, _) -> "_"
    glance.VariableType(_, name) -> name
    glance.HoleType(_, _) -> "_"
  }
}

fn find_identity(def: SchemaDefinition, entity: EntityDefinition) -> IdentityTypeDefinition {
  let assert Ok(id) =
    list.find(def.identities, fn(i) { i.type_name == entity.identity_type_name })
  id
}

fn type_expr_is_calendar_date(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Date", _, []) -> True
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "Date", _, [])]) -> True
    _ -> False
  }
}

fn field_is_calendar_date(f: FieldDefinition) -> Bool {
  type_expr_is_calendar_date(f.type_)
}

fn schema_uses_calendar_date(def: SchemaDefinition) -> Bool {
  list.any(def.entities, fn(e) {
    list.any(e.fields, fn(f) { field_is_calendar_date(f) })
    || {
      let id = find_identity(def, e)
      list.any(id.variants, fn(v) {
        list.any(v.fields, fn(f) { field_is_calendar_date(f) })
      })
    }
  })
}

fn entity_has_relationships_field(entity: EntityDefinition) -> Bool {
  list.any(entity.fields, fn(f) { f.label == "relationships" })
}

fn entity_needs_rich_row_decoder(
  entity: EntityDefinition,
  ctx: TypeCtx,
) -> Bool {
  entity_has_relationships_field(entity)
  || list.any(api_sql.entity_data_fields(entity), fn(f) {
    field_is_calendar_date(f)
    || case f.type_ {
      glance.NamedType(_, "Option", _, [glance.NamedType(_, n, None, [])]) ->
        list.contains(ctx.scalar_names, n)
      _ -> False
    }
  })
}

fn default_relationships_record(
  schema: SchemaDefinition,
  entity: EntityDefinition,
) -> String {
  let assert Ok(rel_field) =
    list.find(entity.fields, fn(f) { f.label == "relationships" })
  let rel_type = case rel_field.type_ {
    glance.NamedType(_, n, None, []) -> n
    glance.NamedType(_, n, Some(_), []) -> n
    _ -> panic as "api: relationships field must be a named type"
  }
  let assert Ok(rc) =
    list.find(schema.relationship_containers, fn(r) {
      r.type_name == rel_type
    })
  let assert Ok(v) = list.first(rc.variants)
  let parts =
    list.map(v.fields, fn(f) { f.label <> ": None" })
    |> string.join(",\n        ")
  rel_type <> "(\n        " <> parts <> ",\n      )"
}

fn rich_identity_construct_call(v: IdentityVariantDefinition) -> String {
  let args =
    list.map(v.fields, fn(f) {
      case type_expr_is_calendar_date(f.type_) {
        True -> f.label <> ": dob_identity"
        False -> f.label <> ": " <> f.label <> "_raw"
      }
    })
    |> string.join(", ")
  v.variant_name <> "(" <> args <> ")"
}

fn data_field_raw_decode_name(f: FieldDefinition) -> String {
  case f.label == "date_of_birth" {
    True -> "dob_raw"
    False -> f.label <> "_raw"
  }
}

fn rich_decode_lets(data_fields: List(FieldDefinition), ctx: TypeCtx) -> String {
  let raw = data_field_raw_decode_name
  list.map(data_fields, fn(f) {
    case f.type_ {
      glance.NamedType(_, "Option", _, [inner]) -> {
        case inner {
          glance.NamedType(_, "String", None, []) ->
            "  let "
            <> f.label
            <> " = opt_string_from_db("
            <> raw(f)
            <> ")"
          glance.NamedType(_, "Date", _, []) ->
            "  let "
            <> f.label
            <> " = case "
            <> raw(f)
            <> " {\n    \"\" -> None\n    s -> Some(date_from_db_string(s))\n  }"
          glance.NamedType(_, n, None, []) ->
            case n == "GenderScalar" {
              True ->
                "  let "
                <> f.label
                <> " = gender_from_db_string("
                <> raw(f)
                <> ")"
              False ->
                case list.contains(ctx.scalar_names, n) {
                  True ->
                    "  let "
                    <> f.label
                    <> " = opt_string_from_db("
                    <> raw(f)
                    <> ")"
                  False ->
                    "  let "
                    <> f.label
                    <> " = opt_string_from_db("
                    <> raw(f)
                    <> ")"
                }
            }
          _ ->
            "  let "
            <> f.label
            <> " = opt_string_from_db("
            <> raw(f)
            <> ")"
        }
      }
      _ ->
        "  let "
        <> f.label
        <> " = opt_string_from_db("
        <> raw(f)
        <> ")"
    }
  })
  |> string.join("\n")
}

fn entity_rich_row_decoder_fn(
  schema: SchemaDefinition,
  entity: EntityDefinition,
  v: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> String {
  let data_fields = api_sql.entity_data_fields(entity)
  let uses =
    list.index_map(data_fields, fn(f, i) {
      let pad = case i {
        0 -> ""
        _ -> "  "
      }
      pad
      <> "use "
      <> data_field_raw_decode_name(f)
      <> " <- decode.field("
      <> int.to_string(i)
      <> ", decode.string)"
    })
    |> string.join("\n")
  let n = list.length(data_fields)
  let use_id = "  use id <- decode.field(" <> int.to_string(n) <> ", decode.int)"
  let use_c =
    "  use created_at <- decode.field(" <> int.to_string(n + 1) <> ", decode.int)"
  let use_u =
    "  use updated_at <- decode.field(" <> int.to_string(n + 2) <> ", decode.int)"
  let use_d =
    "  use deleted_at_raw <- decode.field("
    <> int.to_string(n + 3)
    <> ", decode.optional(decode.int))"
  let lets = rich_decode_lets(data_fields, ctx)
  let needs_dob_assert =
    list.any(v.fields, fn(f) { type_expr_is_calendar_date(f.type_) })
  let assert_line = case needs_dob_assert {
    True -> "\n  let assert Some(dob_identity) = date_of_birth\n"
    False -> ""
  }
  let row_intro = case needs_dob_assert {
    True -> "  let "
    False -> "\n  let "
  }
  let row_local = string.lowercase(entity.type_name)
  let field_lines =
    list.map(data_fields, fn(f) { "      " <> f.label <> ":," })
    |> string.join("\n")
  let ident =
    "      identities: " <> rich_identity_construct_call(v) <> ","
  let rel =
    "      relationships: " <> default_relationships_record(schema, entity) <> ","
  uses
  <> "\n"
  <> use_id
  <> "\n"
  <> use_c
  <> "\n"
  <> use_u
  <> "\n"
  <> use_d
  <> "\n"
  <> lets
  <> assert_line
  <> row_intro
  <> row_local
  <> " =\n    "
  <> entity.type_name
  <> "(\n"
  <> field_lines
  <> "\n"
  <> ident
  <> "\n"
  <> rel
  <> "\n    )\n  decode.success(#(\n    "
  <> row_local
  <> ",\n    magic_from_db_row(id, created_at, updated_at, deleted_at_raw),\n  ))"
}

fn entity_row_tuple_type(entity_name: String) -> String {
  "#(" <> entity_name <> ", dsl.MagicFields)"
}

fn conn_param() -> gparam.Parameter(gtypes.Dynamic) {
  gparam.new("conn", gtypes.raw("sqlight.Connection"))
  |> gparam.to_dynamic
}

fn row_decoder_expr(field_type: glance.Type) -> String {
  let base = case field_type {
    glance.NamedType(_, "Option", _, [inner]) -> inner
    _ -> field_type
  }
  case base {
    glance.NamedType(_, "Int", None, []) -> "decode.int"
    glance.NamedType(_, "Float", None, []) -> "decode.float"
    glance.NamedType(_, "String", None, []) -> "decode.string"
    glance.NamedType(_, "Bool", None, []) ->
      "decode.map(decode.int, fn(i) { i != 0 })"
    _ -> "decode.string"
  }
}

fn id_labels_list(variant: IdentityVariantDefinition) -> List(String) {
  list.map(variant.fields, fn(f) { f.label })
}

fn entity_non_id_fields(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
) -> List(FieldDefinition) {
  let labels = id_labels_list(variant)
  list.filter(api_sql.entity_data_fields(entity), fn(f) {
    !list.contains(labels, f.label)
  })
}

fn entity_needs_opt_text_for_db(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
) -> Bool {
  list.any(entity_non_id_fields(entity, variant), fn(f) {
    case f.type_ {
      glance.NamedType(_, "Option", _, [glance.NamedType(_, "String", None, [])]) ->
        True
      _ -> False
    }
  })
}

fn entity_needs_opt_float_for_db(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
) -> Bool {
  list.any(entity_non_id_fields(entity, variant), fn(f) {
    case f.type_ {
      glance.NamedType(_, "Option", _, [glance.NamedType(_, "Float", None, [])]) ->
        True
      _ -> False
    }
  })
}

fn entity_needs_opt_int_for_db(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
) -> Bool {
  list.any(entity_non_id_fields(entity, variant), fn(f) {
    case f.type_ {
      glance.NamedType(_, "Option", _, [glance.NamedType(_, "Int", None, [])]) ->
        True
      _ -> False
    }
  })
}

fn entity_uses_gender_scalar(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> Bool {
  list.contains(entity_used_scalar_type_names(def, entity), "GenderScalar")
}

fn api_date_panic_label(schema_path: String) -> String {
  string.replace(import_alias(schema_path), "_schema", "_db/api")
  <> ": expected YYYY-MM-DD date string"
}

fn field_to_constructor_arg(f: FieldDefinition, ids: List(String), var: String) -> String {
  let in_id = list.contains(ids, f.label)
  case in_id {
    True ->
      case type_is_option(f.type_) {
        True -> "Some(" <> var <> ")"
        False -> var
      }
    False ->
      case type_is_option(f.type_), type_is_option_string(f.type_) {
        True, True -> "opt_string_from_db(" <> var <> ")"
        True, False -> "Some(" <> var <> ")"
        False, _ -> var
      }
  }
}

fn type_is_option_string(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "String", None, [])]) ->
      True
    _ -> False
  }
}

fn type_is_option(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Option", _, _) -> True
    _ -> False
  }
}

fn identity_construct_call(v: IdentityVariantDefinition) -> String {
  let args =
    list.map(v.fields, fn(f) { f.label <> ":" })
    |> string.join(", ")
  v.variant_name <> "(" <> args <> ")"
}

fn entity_simple_magic_decoder_fn(
  entity: EntityDefinition,
  v: IdentityVariantDefinition,
) -> String {
  let data_fields = api_sql.entity_data_fields(entity)
  let ids = id_labels_list(v)
  let uses =
    list.index_map(data_fields, fn(f, i) {
      let pad = case i {
        0 -> ""
        _ -> "  "
      }
      pad
      <> "use "
      <> f.label
      <> " <- decode.field("
      <> int.to_string(i)
      <> ", "
      <> row_decoder_expr(f.type_)
      <> ")"
    })
    |> string.join("\n")
  let n = list.length(data_fields)
  let use_id = "  use id <- decode.field(" <> int.to_string(n) <> ", decode.int)"
  let use_c =
    "  use created_at <- decode.field(" <> int.to_string(n + 1) <> ", decode.int)"
  let use_u =
    "  use updated_at <- decode.field(" <> int.to_string(n + 2) <> ", decode.int)"
  let use_d =
    "  use deleted_at_raw <- decode.field("
    <> int.to_string(n + 3)
    <> ", decode.optional(decode.int))"
  let row_local = string.lowercase(entity.type_name)
  let field_lines =
    list.map(data_fields, fn(f) {
      let var = f.label
      let expr = field_to_constructor_arg(f, ids, var)
      "      " <> f.label <> ": " <> expr <> ","
    })
    |> string.join("\n")
  let ident = "      identities: " <> identity_construct_call(v) <> ","
  uses
  <> "\n"
  <> use_id
  <> "\n"
  <> use_c
  <> "\n"
  <> use_u
  <> "\n"
  <> use_d
  <> "\n  let "
  <> row_local
  <> " =\n    "
  <> entity.type_name
  <> "(\n"
  <> field_lines
  <> "\n"
  <> ident
  <> "\n    )\n  decode.success(#(\n    "
  <> row_local
  <> ",\n    magic_from_db_row(id, created_at, updated_at, deleted_at_raw),\n  ))"
}

fn entity_with_magic_decoder_fn(
  schema: SchemaDefinition,
  entity: EntityDefinition,
  v: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> String {
  case entity_needs_rich_row_decoder(entity, ctx) {
    True -> entity_rich_row_decoder_fn(schema, entity, v, ctx)
    False -> entity_simple_magic_decoder_fn(entity, v)
  }
}

fn sql_doc_comment(
  table: String,
  data_cols: List(String),
  id_cols: List(String),
  returning: List(String),
) -> String {
  let insert_cols = string.join(data_cols, ", ")
  let qmarks =
    list.repeat("?", list.length(data_cols) + 2)
    |> string.join(", ")
  let on_up =
    list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
    |> list.map(fn(c) { c <> " = excluded." <> c })
    |> string.join(",\n//     ")
  let non_id_cols =
    list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
  let where_sql =
    list.map(id_cols, fn(c) { c <> " = ?" })
    |> string.join(" and ")
  let update_example_sets = case non_id_cols {
    [] -> "updated_at = ?"
    cols ->
      string.join(list.map(cols, fn(c) { c <> " = ?" }), ", ")
      <> ", updated_at = ?"
  }
  let returning_full = string.join(returning, ", ")
  let soft_ret_example = string.join(id_cols, ", ")
  "// --- SQL ("
  <> table
  <> " table shape matches `example_migration_"
  <> table
  <> "` / pragma migrations) ---\n//\n// insert into "
  <> table
  <> " ("
  <> insert_cols
  <> ", created_at, updated_at, deleted_at)\n//   values ("
  <> qmarks
  <> ", null)\n//   on conflict("
  <> string.join(id_cols, ", ")
  <> ") do update set\n//     "
  <> on_up
  <> ",\n//     updated_at = excluded.updated_at,\n//     deleted_at = null;\n//\n// select "
  <> string.join(returning, ", ")
  <> " from "
  <> table
  <> "\n//   where "
  <> where_sql
  <> " and deleted_at is null;\n//\n// update "
  <> table
  <> " set "
  <> update_example_sets
  <> "\n//   where "
  <> where_sql
  <> " and deleted_at is null\n//   returning "
  <> returning_full
  <> ";\n//\n// update "
  <> table
  <> " set deleted_at = ?, updated_at = ?\n//   where "
  <> where_sql
  <> " and deleted_at is null\n//   returning "
  <> soft_ret_example
  <> ";\n//\n// select "
  <> string.join(returning, ", ")
  <> " from "
  <> table
  <> "\n//   where deleted_at is null\n//   order by updated_at desc\n//   limit 100;\n\n"
}

fn upsert_gparams(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> List(gparam.Parameter(gtypes.Dynamic)) {
  let id_ps = identity_gparams(variant)
  let labels = id_labels_list(variant)
  let extras =
    api_sql.entity_data_fields(entity)
    |> list.filter(fn(f) { !list.contains(labels, f.label) })
    |> list.map(fn(f) {
      gparam.new(f.label, gtypes.raw(render_type(f.type_, ctx)))
      |> gparam.to_dynamic
    })
  list.append(id_ps, extras)
}

fn identity_gparams(v: IdentityVariantDefinition) -> List(gparam.Parameter(gtypes.Dynamic)) {
  list.map(v.fields, fn(f) {
    gparam.new(f.label, gtypes.raw(sql_types.identity_upsert_param_type(f.type_)))
    |> gparam.to_dynamic
  })
}

fn sql_bind_expr(f: FieldDefinition, value: String) -> String {
  case sql_types.sql_type(f.type_) {
    "int" -> "sqlight.int(" <> value <> ")"
    "real" -> "sqlight.float(" <> value <> ")"
    _ ->
      case field_is_calendar_date(f) {
        True -> "sqlight.text(date_to_db_string(" <> value <> "))"
        False -> "sqlight.text(" <> value <> ")"
      }
  }
}

fn non_id_temp_var(f: FieldDefinition) -> String {
  case render_type_plain(f) {
    "String" -> "c"
    "Float" -> "p"
    "Int" -> "q"
    _ -> "db_" <> f.label
  }
}

fn upsert_fn_body(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  op_prefix: String,
) -> String {
  let labels = id_labels_list(variant)
  let data_fields = api_sql.entity_data_fields(entity)
  let non_id =
    list.filter(data_fields, fn(f) { !list.contains(labels, f.label) })
  let sql_const = case op_prefix {
    "upsert" -> "upsert_sql"
    "update" -> "update_by_" <> id_snake <> "_sql"
    _ -> "upsert_sql"
  }
  let let_lines =
    list.map(non_id, fn(f) {
      case f.type_ {
        glance.NamedType(_, "Option", _, [
          glance.NamedType(_, "GenderScalar", None, []),
        ]) -> ""
        _ -> {
          let v = non_id_temp_var(f)
          case render_type_plain(f) {
            "String" ->
              "  let " <> v <> " = opt_text_for_db(" <> f.label <> ")\n"
            "Float" ->
              "  let " <> v <> " = opt_float_for_db(" <> f.label <> ")\n"
            "Int" ->
              "  let " <> v <> " = opt_int_for_db(" <> f.label <> ")\n"
            _ ->
              "  let " <> v <> " = opt_text_for_db(" <> f.label <> ")\n"
          }
        }
      }
    })
    |> string.concat
  let with_list = case op_prefix {
    "upsert" -> {
      let row_bind = fn(col: String) -> String {
        case list.find(variant.fields, fn(f) { f.label == col }) {
          Ok(f) -> "      " <> sql_bind_expr(f, f.label) <> ","
          Error(_) -> {
            let assert Ok(f) = list.find(non_id, fn(x) { x.label == col })
            let value = case f.type_ {
              glance.NamedType(_, "Option", _, [
                glance.NamedType(_, "GenderScalar", None, []),
              ]) -> "gender_to_db_string(" <> f.label <> ")"
              _ -> non_id_temp_var(f)
            }
            "      " <> sql_bind_expr(f, value) <> ","
          }
        }
      }
      let id_part =
        list.map(list.map(data_fields, fn(f) { f.label }), row_bind)
        |> string.join("\n")
      string.trim_end(
        id_part <> "\n      sqlight.int(now),\n      sqlight.int(now),",
      )
    }
    _ -> {
      let extras =
        list.map(non_id, fn(f) {
          let value = case f.type_ {
            glance.NamedType(_, "Option", _, [
              glance.NamedType(_, "GenderScalar", None, []),
            ]) -> "gender_to_db_string(" <> f.label <> ")"
            _ -> non_id_temp_var(f)
          }
          "      " <> sql_bind_expr(f, value) <> ","
        })
        |> string.join("\n")
      let id_tail =
        list.map(variant.fields, fn(f) {
          "      " <> sql_bind_expr(f, f.label) <> ","
        })
        |> string.join("\n")
      string.trim_end(
        extras <> "\n      sqlight.int(now),\n" <> id_tail,
      )
    }
  }
  let case_rows = case op_prefix {
    "upsert" ->
      "  case rows {\n    [row, ..] -> Ok(row)\n    [] ->\n      Error(sqlight.SqlightError(\n        sqlight.GenericError,\n        \"upsert returned no row\",\n        -1,\n      ))\n  }"
    _ ->
      "  case rows {\n    [row, ..] -> Ok(row)\n    [] -> Error(not_found_error(\"update_"
      <> entity_snake
      <> "_by_"
      <> id_snake
      <> "\"))\n  }"
  }
  let let_block = case let_lines {
    "" -> ""
    s -> s
  }
  "let now = unix_seconds_now()\n"
  <> let_block
  <> "  use rows <- result.try(sqlight.query(\n    "
  <> sql_const
  <> ",\n    on: conn,\n    with: [\n"
  <> with_list
  <> "\n    ],\n    expecting: "
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  ))\n"
  <> case_rows
}

fn render_type_plain(f: FieldDefinition) -> String {
  case f.type_ {
    glance.NamedType(_, "Option", _, [inner]) -> render_type_plain_field(inner)
    _ -> render_type_plain_field(f.type_)
  }
}

fn render_type_plain_field(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Int", None, []) -> "Int"
    glance.NamedType(_, "Float", None, []) -> "Float"
    glance.NamedType(_, "String", None, []) -> "String"
    glance.NamedType(_, "GenderScalar", None, []) -> "GenderScalar"
    _ -> "String"
  }
}

fn get_fn_body(
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
) -> String {
  let with_part = case list.length(variant.fields) > 1 {
    True -> {
      let lines =
        list.map(variant.fields, fn(f) {
          "      " <> sql_bind_expr(f, f.label) <> ","
        })
        |> string.join("\n")
      "[\n" <> lines <> "\n    ]"
    }
    False -> {
      let binds =
        list.map(variant.fields, fn(f) { sql_bind_expr(f, f.label) })
        |> string.join(", ")
      "[" <> binds <> "]"
    }
  }
  "use rows <- result.try(sqlight.query(\n    select_by_"
  <> id_snake
  <> "_sql,\n    on: conn,\n    with: "
  <> with_part
  <> ",\n    expecting: "
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  ))\n  case rows {\n    [] -> Ok(None)\n    [row, ..] -> Ok(Some(row))\n  }"
}

fn delete_fn_body(
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
) -> String {
  let id_binds =
    list.map(variant.fields, fn(f) { sql_bind_expr(f, f.label) })
  let with_elems =
    list.flatten([["sqlight.int(now)", "sqlight.int(now)"], id_binds])
  let with_part = case list.length(variant.fields) > 1 {
    True -> {
      let lines =
        list.map(with_elems, fn(e) { "        " <> e <> "," })
        |> string.join("\n")
      "[\n" <> lines <> "\n      ]"
    }
    False -> "[" <> string.join(with_elems, ", ") <> "]"
  }
  "let now = unix_seconds_now()\n  use rows <- result.try(\n    sqlight.query(\n      soft_delete_by_"
  <> id_snake
  <> "_sql,\n      on: conn,\n      with: "
  <> with_part
  <> ",\n      expecting: {\n        use _n <- decode.field(0, decode.string)\n        decode.success(Nil)\n      },\n    ),\n  )\n  case rows {\n    [Nil, ..] -> Ok(Nil)\n    [] -> Error(not_found_error(\"delete_"
  <> entity_snake
  <> "_by_"
  <> id_snake
  <> "\"))\n  }"
}

fn last_fn_body(entity_snake: String) -> String {
  "sqlight.query(\n    last_100_sql,\n    on: conn,\n    with: [],\n    expecting: "
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  )"
}

fn query_sql_const_name(spec_name: String) -> String {
  case string.starts_with(spec_name, "query_") {
    True -> string.drop_start(spec_name, 6) <> "_sql"
    False -> spec_name <> "_sql"
  }
}

fn cheap_query_sql(
  def: SchemaDefinition,
  entity: EntityDefinition,
  table: String,
  returning: List(String),
) -> Option(String) {
  case
    list.any(def.queries, fn(q) { q.name == "query_cheap_fruit" })
    && entity.type_name == "Fruit"
  {
    False -> None
    True -> Some(api_sql.cheap_by_price_sql(table, returning))
  }
}

fn query_cheap_fruit_body(entity_snake: String, sql_name: String) -> String {
  "sqlight.query(\n    "
  <> sql_name
  <> ",\n    on: conn,\n    with: [sqlight.float(max_price)],\n    expecting: "
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  )"
}

fn pascal_to_snake(s: String) -> String {
  let cps = string.to_utf_codepoints(s)
  let out =
    list.index_fold(cps, [], fn(acc, cp, i) {
      let lower = ascii_lower_codepoint(cp)
      case i > 0 && is_upper_ascii(cp) {
        True -> list.append(acc, [underscore_cp(), lower])
        False -> list.append(acc, [lower])
      }
    })
  string.from_utf_codepoints(out)
}

fn underscore_cp() {
  let assert Ok(cp) = string.utf_codepoint(95)
  cp
}

fn is_upper_ascii(cp) -> Bool {
  let i = string.utf_codepoint_to_int(cp)
  i >= 65 && i <= 90
}

fn ascii_lower_codepoint(cp) {
  let i = string.utf_codepoint_to_int(cp)
  case i >= 65 && i <= 90 {
    True -> {
      let assert Ok(lower) = string.utf_codepoint(i + 32)
      lower
    }
    False -> cp
  }
}

fn with_api_imports(
  migration_path: String,
  schema_path: String,
  def: SchemaDefinition,
  exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let mig_parts = string.split(migration_path, "/")
  let sch_parts = string.split(schema_path, "/")
  let after_result = fn() -> gmod.Module {
    case schema_uses_calendar_date(def) {
      False ->
        gmod.with_import(
          gimport.new_predefined(["gleam", "time", "timestamp"]),
          fn(_) {
            gmod.with_import(gimport.new_predefined(["sqlight"]), fn(_) { inner() })
          },
        )
      True ->
        gmod.with_import(gimport.new_predefined(["gleam", "int"]), fn(_) {
          gmod.with_import(gimport.new_predefined(["gleam", "string"]), fn(_) {
            gmod.with_import(
              gimport.new_with_exposing(
                ["gleam", "time", "calendar"],
                "type Date, Date as CalDate, month_from_int, month_to_int",
              ),
              fn(_) {
                gmod.with_import(
                  gimport.new_predefined(["gleam", "time", "timestamp"]),
                  fn(_) {
                    gmod.with_import(gimport.new_predefined(["sqlight"]), fn(_) {
                      inner()
                    })
                  },
                )
              },
            )
          })
        })
    }
  }
  gmod.with_import(gimport.new(mig_parts), fn(_) {
    gmod.with_import(gimport.new_with_exposing(sch_parts, exposing), fn(_) {
      gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"), fn(_) {
        gmod.with_import(
          gimport.new_predefined(["gleam", "dynamic", "decode"]),
          fn(_) {
            gmod.with_import(
              gimport.new_with_exposing(["gleam", "option"], "type Option, None, Some"),
              fn(_) {
                gmod.with_import(gimport.new_predefined(["gleam", "result"]), fn(_) {
                  after_result()
                })
              },
            )
          },
        )
      })
    })
  })
}

fn build_module(path: String, def: SchemaDefinition) -> gmod.Module {
  let assert [entity, ..] = def.entities
  let ctx = type_ctx(path, def)
  let exposing = api_schema_exposing(def, entity)
  let migration_path = migration_import_path(path)
  let id = find_identity(def, entity)
  let assert Ok(variant) = list.first(id.variants)
  let table = string.lowercase(entity.type_name)
  let data_fields = api_sql.entity_data_fields(entity)
  let data_col_labels = list.map(data_fields, fn(f) { f.label })
  let id_cols = list.map(variant.fields, fn(f) { f.label })
  let returning = api_sql.full_row_columns(data_col_labels)
  let entity_snake = string.lowercase(entity.type_name)
  let id_snake =
    case string.starts_with(variant.variant_name, "By") {
      True -> pascal_to_snake(string.drop_start(variant.variant_name, 2))
      False -> pascal_to_snake(variant.variant_name)
    }
  let sql_comment = sql_doc_comment(table, data_col_labels, id_cols, returning)

  let upsert_s =
    api_sql.upsert_sql(table, data_col_labels, id_cols, returning)
  let select_s = api_sql.select_by_identity_sql(table, returning, id_cols)
  let update_s =
    api_sql.update_by_identity_sql(table, data_col_labels, id_cols, returning)
  let soft_s =
    api_sql.soft_delete_by_identity_sql(
      table,
      id_cols,
      api_sql.soft_delete_returning(id_cols),
    )
  let last_s = api_sql.last_100_sql(table, returning)
  let cheap_opt = cheap_query_sql(def, entity, table, returning)

  let row_t = gtypes.raw(entity_row_tuple_type(entity.type_name))
  let sql_err = gtypes.raw("sqlight.Error")
  let upsert_params =
    list.append([conn_param()], upsert_gparams(entity, variant, ctx))
  let get_params = list.append([conn_param()], identity_gparams(variant))

  let date_panic = api_date_panic_label(path)
  let opt_int_chunk = #(
    gdef.new("opt_int_for_db") |> gdef.with_publicity(False),
    gfun.new_raw(
      [gparam.new("o", gtypes.raw("Option(Int)")) |> gparam.to_dynamic],
      gtypes.int,
      fn(_) {
        gexpr.raw("case o {\n    Some(i) -> i\n    None -> 0\n  }")
      },
    )
      |> gfun.to_dynamic,
  )
  let opt_float_chunk = #(
    gdef.new("opt_float_for_db") |> gdef.with_publicity(False),
    gfun.new_raw(
      [gparam.new("o", gtypes.raw("Option(Float)")) |> gparam.to_dynamic],
      gtypes.float,
      fn(_) {
        gexpr.raw("case o {\n    Some(f) -> f\n    None -> 0.0\n  }")
      },
    )
      |> gfun.to_dynamic,
  )
  let opt_text_chunk = #(
    gdef.new("opt_text_for_db") |> gdef.with_publicity(False),
    gfun.new_raw(
      [gparam.new("o", gtypes.raw("Option(String)")) |> gparam.to_dynamic],
      gtypes.string,
      fn(_) {
        gexpr.raw("case o {\n    Some(s) -> s\n    None -> \"\"\n  }")
      },
    )
      |> gfun.to_dynamic,
  )
  let optional_opt_chunks =
    list.flatten([
      case entity_needs_opt_int_for_db(entity, variant) {
        True -> [opt_int_chunk]
        False -> []
      },
      case entity_needs_opt_float_for_db(entity, variant) {
        True -> [opt_float_chunk]
        False -> []
      },
      case entity_needs_opt_text_for_db(entity, variant) {
        True -> [opt_text_chunk]
        False -> []
      },
    ])
  let gender_scalar_chunks = case entity_uses_gender_scalar(def, entity) {
    True -> [
      #(
        gdef.new("gender_from_db_string") |> gdef.with_publicity(False),
        gfun.new_raw(
          [gparam.new("s", gtypes.string) |> gparam.to_dynamic],
          gtypes.raw("Option(GenderScalar)"),
          fn(_) {
            gexpr.raw(
              "case s {\n    \"\" -> None\n    \"Male\" -> Some(Male)\n    \"Female\" -> Some(Female)\n    _ -> None\n  }",
            )
          },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gdef.new("gender_to_db_string") |> gdef.with_publicity(False),
        gfun.new_raw(
          [gparam.new("o", gtypes.raw("Option(GenderScalar)")) |> gparam.to_dynamic],
          gtypes.string,
          fn(_) {
            gexpr.raw(
              "case o {\n    None -> \"\"\n    Some(Male) -> \"Male\"\n    Some(Female) -> \"Female\"\n  }",
            )
          },
        )
          |> gfun.to_dynamic,
      ),
    ]
    False -> []
  }
  let calendar_chunks = case schema_uses_calendar_date(def) {
    True -> [
      #(
        gdef.new("date_from_db_string") |> gdef.with_publicity(False),
        gfun.new_raw(
          [gparam.new("s", gtypes.string) |> gparam.to_dynamic],
          gtypes.raw("Date"),
          fn(_) {
            gexpr.raw(
              "case string.split(s, \"-\") {\n    [ys, ms, ds] -> {\n      let assert Ok(y) = int.parse(ys)\n      let assert Ok(mi) = int.parse(ms)\n      let assert Ok(d) = int.parse(ds)\n      let assert Ok(month) = month_from_int(mi)\n      CalDate(y, month, d)\n    }\n    _ -> panic as \""
              <> date_panic
              <> "\"\n  }",
            )
          },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gdef.new("date_to_db_string") |> gdef.with_publicity(False),
        gfun.new_raw(
          [gparam.new("d", gtypes.raw("Date")) |> gparam.to_dynamic],
          gtypes.string,
          fn(_) {
            gexpr.raw(
              "let CalDate(year:, month:, day:) = d\n  int.to_string(year)\n  <> \"-\"\n  <> pad2(month_to_int(month))\n  <> \"-\"\n  <> pad2(day)",
            )
          },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gdef.new("pad2") |> gdef.with_publicity(False),
        gfun.new_raw(
          [gparam.new("n", gtypes.int) |> gparam.to_dynamic],
          gtypes.string,
          fn(_) {
            gexpr.raw(
              "let s = int.to_string(n)\n  case string.length(s) {\n    1 -> \"0\" <> s\n    _ -> s\n  }",
            )
          },
        )
          |> gfun.to_dynamic,
      ),
    ]
    False -> []
  }
  let pre_unix_helpers =
    list.flatten([gender_scalar_chunks, calendar_chunks])

  let query_chunk = case cheap_opt {
    None -> []
    Some(_) -> {
      let body =
        query_cheap_fruit_body(entity_snake, query_sql_const_name("query_cheap_fruit"))
      [
        #(
          gleamgen_emit.pub_def("query_cheap_fruit")
            |> gdef.with_text_before(
              "/// Fruits with `price < max_price`, ordered by ascending price (see `query_cheap_fruit` spec).\n",
            ),
          gfun.new_raw(
            [
              conn_param(),
              gparam.new("max_price", gtypes.float) |> gparam.to_dynamic,
            ],
            gtypes.result(gtypes.list(row_t), sql_err),
            fn(_) { gexpr.raw(body) },
          )
            |> gfun.to_dynamic,
        ),
      ]
    }
  }

  let fn_chunks =
    list.flatten([
      query_chunk,
      [
        #(
          gleamgen_emit.pub_def("last_100_edited_" <> entity_snake)
            |> gdef.with_text_before(
              "/// List up to 100 recently edited "
              <> entity_snake
              <> " rows.\n",
            ),
          gfun.new_raw([conn_param()], gtypes.result(gtypes.list(row_t), sql_err), fn(_) {
            gexpr.raw(last_fn_body(entity_snake))
          })
            |> gfun.to_dynamic,
        ),
        #(
          gleamgen_emit.pub_def("delete_" <> entity_snake <> "_by_" <> id_snake)
            |> gdef.with_text_before(
              "/// Delete a "
              <> entity_snake
              <> " by the `"
              <> variant.variant_name
              <> "` identity.\n",
            ),
          gfun.new_raw(get_params, gtypes.result(gtypes.nil, sql_err), fn(_) {
            gexpr.raw(delete_fn_body(variant, entity_snake, id_snake))
          })
            |> gfun.to_dynamic,
        ),
        #(
          gleamgen_emit.pub_def("update_" <> entity_snake <> "_by_" <> id_snake)
            |> gdef.with_text_before(
              "/// Update a "
              <> entity_snake
              <> " by the `"
              <> variant.variant_name
              <> "` identity.\n",
            ),
          gfun.new_raw(upsert_params, gtypes.result(row_t, sql_err), fn(_) {
            gexpr.raw(upsert_fn_body(
              entity,
              variant,
              entity_snake,
              id_snake,
              "update",
            ))
          })
            |> gfun.to_dynamic,
        ),
        #(
          gleamgen_emit.pub_def("get_" <> entity_snake <> "_by_" <> id_snake)
            |> gdef.with_text_before(
              "/// Get a "
              <> entity_snake
              <> " by the `"
              <> variant.variant_name
              <> "` identity.\n",
            ),
          gfun.new_raw(
            get_params,
            gtypes.result(
              gtypes.raw(
                "Option(" <> entity_row_tuple_type(entity.type_name) <> ")",
              ),
              sql_err,
            ),
            fn(_) { gexpr.raw(get_fn_body(variant, entity_snake, id_snake)) },
          )
            |> gfun.to_dynamic,
        ),
        #(
          gleamgen_emit.pub_def("upsert_" <> entity_snake <> "_by_" <> id_snake)
            |> gdef.with_text_before(
              "/// Upsert a "
              <> entity_snake
              <> " by the `"
              <> variant.variant_name
              <> "` identity.\n",
            ),
          gfun.new_raw(upsert_params, gtypes.result(row_t, sql_err), fn(_) {
            gexpr.raw(upsert_fn_body(
              entity,
              variant,
              entity_snake,
              id_snake,
              "upsert",
            ))
          })
            |> gfun.to_dynamic,
        ),
        #(
          gleamgen_emit.pub_def("migrate"),
          gfun.new_raw(
            [conn_param()],
            gtypes.result(gtypes.nil, sql_err),
            fn(_) { gexpr.raw("migration.migration(conn)") },
          )
            |> gfun.to_dynamic,
        ),
        #(
          gdef.new("not_found_error") |> gdef.with_publicity(False),
          gfun.new_raw(
            [gparam.new("op", gtypes.string) |> gparam.to_dynamic],
            gtypes.raw("sqlight.Error"),
            fn(_) {
              gexpr.raw(
                "sqlight.SqlightError(sqlight.GenericError, \""
                <> entity_snake
                <> " not found: \" <> op, -1)",
              )
            },
          )
            |> gfun.to_dynamic,
        ),
        #(
          gdef.new(entity_snake <> "_with_magic_row_decoder")
            |> gdef.with_publicity(False),
          gfun.new_raw(
            [],
            gtypes.raw(
              "decode.Decoder(" <> entity_row_tuple_type(entity.type_name) <> ")",
            ),
            fn(_) {
              gexpr.raw(entity_with_magic_decoder_fn(def, entity, variant, ctx))
            },
          )
            |> gfun.to_dynamic,
        ),
        #(
          gdef.new("magic_from_db_row") |> gdef.with_publicity(False),
          gfun.new_raw(
            [
              gparam.new("id", gtypes.int) |> gparam.to_dynamic,
              gparam.new("created_s", gtypes.int) |> gparam.to_dynamic,
              gparam.new("updated_s", gtypes.int) |> gparam.to_dynamic,
              gparam.new("deleted_raw", gtypes.raw("Option(Int)"))
                |> gparam.to_dynamic,
            ],
            gtypes.raw("dsl.MagicFields"),
            fn(_) {
              gexpr.raw(
                "dsl.MagicFields(\n    id:,\n    created_at: timestamp.from_unix_seconds(created_s),\n    updated_at: timestamp.from_unix_seconds(updated_s),\n    deleted_at: case deleted_raw {\n      Some(s) -> Some(timestamp.from_unix_seconds(s))\n      None -> None\n    },\n  )",
              )
            },
          )
            |> gfun.to_dynamic,
        ),
        #(
          gdef.new("opt_string_from_db") |> gdef.with_publicity(False),
          gfun.new_raw(
            [gparam.new("s", gtypes.string) |> gparam.to_dynamic],
            gtypes.raw("Option(String)"),
            fn(_) {
              gexpr.raw("case s {\n    \"\" -> None\n    _ -> Some(s)\n  }")
            },
          )
            |> gfun.to_dynamic,
        ),
      ],
      optional_opt_chunks,
      pre_unix_helpers,
      [
        #(
          gdef.new("unix_seconds_now") |> gdef.with_publicity(False),
          gfun.new_raw([], gtypes.int, fn(_) {
            gexpr.raw(
              "let #(s, _) =\n    timestamp.system_time()\n    |> timestamp.to_unix_seconds_and_nanoseconds\n  s",
            )
          })
            |> gfun.to_dynamic,
        ),
      ],
    ])

  let with_functions =
    list.fold(fn_chunks, gmod.eof(), fn(acc, chunk) {
      let #(def_f, fun) = chunk
      gmod.with_function(def_f, fun, fn(_) { acc })
    })

  let cheap_const_name = query_sql_const_name("query_cheap_fruit")
  let const_entries =
    list.flatten([
      [
        #(cheap_const_name, cheap_opt, False),
        #("last_100_sql", Some(last_s), False),
        #(
          "soft_delete_by_" <> id_snake <> "_sql",
          Some(soft_s),
          False,
        ),
        #("update_by_" <> id_snake <> "_sql", Some(update_s), False),
        #("select_by_" <> id_snake <> "_sql", Some(select_s), False),
        #("upsert_sql", Some(upsert_s), True),
      ],
    ])

  let with_constants =
    list.fold(const_entries, with_functions, fn(acc, entry) {
      let #(name, val_opt, comment) = entry
      case val_opt {
        None -> acc
        Some(v) -> {
          let def_c =
            case comment {
              True -> gdef.new(name) |> gdef.with_text_before(sql_comment)
              False -> gdef.new(name)
            }
          gmod.with_constant(def_c, gexpr.string(v), fn(_) { acc })
        }
      }
    })

  with_api_imports(migration_path, path, def, exposing, fn() { with_constants })
}
