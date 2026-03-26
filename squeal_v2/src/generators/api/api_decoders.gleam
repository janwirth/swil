import generators/api/api_sql
import glance
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/expression/case_ as gcase
import gleamgen/function as gfun
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition, type IdentityVariantDefinition,
  type SchemaDefinition,
}

pub type TypeCtx {
  TypeCtx(
    schema_alias: String,
    entity_names: List(String),
    scalar_names: List(String),
  )
}

fn import_alias(path: String) -> String {
  case string.split(path, "/") |> list.reverse() {
    [a, ..] -> a
    [] -> path
  }
}

pub fn type_ctx(schema_path: String, def: SchemaDefinition) -> TypeCtx {
  TypeCtx(
    schema_alias: import_alias(schema_path),
    entity_names: list.map(def.entities, fn(e) { e.type_name }),
    scalar_names: list.map(def.scalars, fn(s) { s.type_name }),
  )
}

pub fn render_type(t: glance.Type, ctx: TypeCtx) -> String {
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

fn type_expr_is_calendar_date(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Date", _, []) -> True
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "Date", _, [])]) ->
      True
    _ -> False
  }
}

pub fn field_is_calendar_date(f: FieldDefinition) -> Bool {
  type_expr_is_calendar_date(f.type_)
}

fn entity_has_relationships_field(entity: EntityDefinition) -> Bool {
  list.any(entity.fields, fn(f) { f.label == "relationships" })
}

fn entity_needs_rich_row_decoder(entity: EntityDefinition, ctx: TypeCtx) -> Bool {
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
    list.find(schema.relationship_containers, fn(r) { r.type_name == rel_type })
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
            "  let " <> f.label <> " = opt_string_from_db(" <> raw(f) <> ")"
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
          _ -> "  let " <> f.label <> " = opt_string_from_db(" <> raw(f) <> ")"
        }
      }
      _ -> "  let " <> f.label <> " = opt_string_from_db(" <> raw(f) <> ")"
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
  let use_id =
    "  use id <- decode.field(" <> int.to_string(n) <> ", decode.int)"
  let use_c =
    "  use created_at <- decode.field("
    <> int.to_string(n + 1)
    <> ", decode.int)"
  let use_u =
    "  use updated_at <- decode.field("
    <> int.to_string(n + 2)
    <> ", decode.int)"
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
  let ident = "      identities: " <> rich_identity_construct_call(v) <> ","
  let rel =
    "      relationships: "
    <> default_relationships_record(schema, entity)
    <> ","
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

pub fn entity_row_tuple_type(entity_name: String) -> String {
  "#(" <> entity_name <> ", dsl.MagicFields)"
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

pub fn id_labels_list(variant: IdentityVariantDefinition) -> List(String) {
  list.map(variant.fields, fn(f) { f.label })
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

fn field_to_constructor_arg(
  f: FieldDefinition,
  ids: List(String),
  var: String,
) -> String {
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
  let use_id =
    "  use id <- decode.field(" <> int.to_string(n) <> ", decode.int)"
  let use_c =
    "  use created_at <- decode.field("
    <> int.to_string(n + 1)
    <> ", decode.int)"
  let use_u =
    "  use updated_at <- decode.field("
    <> int.to_string(n + 2)
    <> ", decode.int)"
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

fn opt_string_from_db_fun() -> gfun.Function(gtypes.Dynamic, gtypes.Dynamic) {
  gfun.new1(
    gparam.new("s", gtypes.string) |> gparam.to_dynamic,
    gtypes.raw("Option(String)"),
    fn(s) {
      gcase.new(s)
      |> gcase.with_pattern(gpat.string_literal(""), fn(_) { gexpr.raw("None") })
      |> gcase.with_pattern(gpat.discard(), fn(_) {
        gexpr.call1(gexpr.raw("Some"), s)
      })
      |> gcase.build_expression()
    },
  )
  |> gfun.to_dynamic
}

pub fn row_decode_helpers_fn_chunks(
  entity_snake: String,
  schema: SchemaDefinition,
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> List(#(gdef.Definition, gfun.Function(gtypes.Dynamic, gtypes.Dynamic))) {
  [
    #(
      gdef.new(entity_snake <> "_with_magic_row_decoder")
        |> gdef.with_publicity(False),
      gfun.new_raw(
        [],
        gtypes.raw(
          "decode.Decoder(" <> entity_row_tuple_type(entity.type_name) <> ")",
        ),
        fn(_) {
          gexpr.raw(entity_with_magic_decoder_fn(schema, entity, variant, ctx))
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
      opt_string_from_db_fun(),
    ),
  ]
}
