import generators/api/api_sql
import generators/api/api_subset
import generators/gleamgen_emit
import generators/sql_types as sql_t
import glance
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module/definition as gdef
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition, type IdentityVariantDefinition,
  type QuerySpecDefinition, type SchemaDefinition,
}

pub type TypeCtx {
  TypeCtx(
    schema_alias: String,
    entity_names: List(String),
    scalar_names: List(String),
    relationship_container_names: List(String),
    /// `*Scalar` types whose variants are all payload-free (enum string storage in SQL).
    enum_scalar_names: List(String),
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
    relationship_container_names: list.map(def.relationship_containers, fn(r) {
      r.type_name
    }),
    enum_scalar_names: def.scalars
      |> list.filter(fn(s) { s.enum_only })
      |> list.map(fn(s) { s.type_name }),
  )
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

/// Stable file-local name prefix for SQL text helpers (e.g. `GenderScalar` → `gender_scalar`).
pub fn scalar_type_snake_case(type_name: String) -> String {
  let cps = string.to_utf_codepoints(type_name)
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

pub fn scalar_from_db_fn_name(type_name: String) -> String {
  scalar_type_snake_case(type_name) <> "_from_db_string"
}

pub fn scalar_to_db_fn_name(type_name: String) -> String {
  scalar_type_snake_case(type_name) <> "_to_db_string"
}

fn schema_qualified_name(name: String, ctx: TypeCtx) -> Bool {
  list.contains(ctx.scalar_names, name)
  || list.contains(ctx.entity_names, name)
  || list.contains(ctx.relationship_container_names, name)
  // Public type aliases (not `pub type X { ... }`) are omitted from `scalar_names`.
  || name == "FilterExpressionScalar"
}

fn render_named_simple(name: String, ctx: TypeCtx) -> String {
  case schema_qualified_name(name, ctx) {
    True -> ctx.schema_alias <> "." <> name
    False -> name
  }
}

pub fn render_type(t: glance.Type, ctx: TypeCtx) -> String {
  case t {
    glance.NamedType(_, "MagicFields", _, []) -> "dsl.MagicFields"
    glance.NamedType(_, "String", None, []) -> "String"
    glance.NamedType(_, "Int", None, []) -> "Int"
    glance.NamedType(_, "Float", None, []) -> "Float"
    glance.NamedType(_, "Bool", None, []) -> "Bool"
    glance.NamedType(_, "Date", _, []) -> "calendar.Date"
    glance.NamedType(_, "Timestamp", _, []) -> "Timestamp"
    glance.NamedType(_, "Option", _, [inner]) ->
      "option.Option(" <> render_type(inner, ctx) <> ")"
    glance.NamedType(_, "List", _, [inner]) ->
      "List(" <> render_type(inner, ctx) <> ")"
    glance.NamedType(_, name, None, []) -> render_named_simple(name, ctx)
    glance.NamedType(_, name, Some(_), []) -> render_named_simple(name, ctx)
    glance.NamedType(_, name, _, params) ->
      render_named_simple(name, ctx)
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

fn entity_needs_rich_row_decoder(
  entity: EntityDefinition,
  _ctx: TypeCtx,
) -> Bool {
  entity_has_relationships_field(entity)
  || list.any(api_sql.entity_data_fields(entity), fn(f) {
    field_is_calendar_date(f)
  })
}

fn default_relationships_record(
  schema: SchemaDefinition,
  entity: EntityDefinition,
  ctx: TypeCtx,
) -> String {
  let rel_field = case
    list.find(entity.fields, fn(f) { f.label == "relationships" })
  {
    Ok(f) -> f
    Error(Nil) -> {
      let msg =
        "api_decoders.default_relationships_record: entity "
        <> entity.type_name
        <> " has no `relationships` field, but a relationships record was requested"
      panic as msg
    }
  }
  let rel_type = case rel_field.type_ {
    glance.NamedType(_, n, None, []) -> n
    glance.NamedType(_, n, Some(_), []) -> n
    _ -> {
      let msg =
        "api_decoders.default_relationships_record: entity "
        <> entity.type_name
        <> " has `relationships` field with unsupported type; expected named custom type"
      panic as msg
    }
  }
  let rc = case
    list.find(schema.relationship_containers, fn(r) { r.type_name == rel_type })
  {
    Ok(found) -> found
    Error(Nil) -> {
      let msg =
        "api_decoders.default_relationships_record: missing relationship container type "
        <> rel_type
        <> " for entity "
        <> entity.type_name
      panic as msg
    }
  }
  let v = case list.first(rc.variants) {
    Ok(found) -> found
    Error(Nil) -> {
      let msg =
        "api_decoders.default_relationships_record: relationship container "
        <> rel_type
        <> " has no variants"
      panic as msg
    }
  }
  let parts =
    list.map(v.fields, fn(f) {
      f.label <> ": " <> relationship_default_expr(f.type_)
    })
    |> string.join(",\n        ")
  ctx.schema_alias <> "." <> rel_type <> "(\n        " <> parts <> ",\n      )"
}

fn relationship_default_expr(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Option", _, _) -> "option.None"
    glance.NamedType(_, "BacklinkWith", _, _) ->
      "dsl.BacklinkWith([], option.None)"
    glance.NamedType(_, "List", _, _) -> "[]"
    _ -> "option.None"
  }
}

fn rich_identity_construct_call(
  v: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> String {
  let args =
    list.map(v.fields, fn(f) {
      case type_expr_is_calendar_date(f.type_) {
        True -> f.label <> ": dob_identity"
        False -> f.label <> ": " <> f.label <> "_raw"
      }
    })
    |> string.join(", ")
  ctx.schema_alias <> "." <> v.variant_name <> "(" <> args <> ")"
}

fn data_field_raw_decode_name(f: FieldDefinition) -> String {
  case f.label == "date_of_birth" {
    True -> "dob_raw"
    False -> f.label <> "_raw"
  }
}

fn rich_row_data_field_decode_subexpr(f: FieldDefinition) -> String {
  case sql_t.type_stored_as_unix_int(f.type_) {
    True -> "decode.int"
    False -> "decode.string"
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
            <> " = api_help.opt_string_from_db("
            <> raw(f)
            <> ")"
          glance.NamedType(_, "Date", _, []) ->
            "  let "
            <> f.label
            <> " = case "
            <> raw(f)
            <> " {\n    \"\" -> option.None\n    s -> option.Some(api_help.date_from_db_string(s))\n  }"
          glance.NamedType(_, "Timestamp", _, []) ->
            "  let "
            <> f.label
            <> " = api_help.opt_timestamp_from_db("
            <> raw(f)
            <> ")"
          glance.NamedType(_, n, _, []) ->
            case list.contains(ctx.enum_scalar_names, n) {
              True ->
                "  let "
                <> f.label
                <> " = "
                <> scalar_from_db_fn_name(n)
                <> "("
                <> raw(f)
                <> ")"
              False ->
                "  let "
                <> f.label
                <> " = api_help.opt_string_from_db("
                <> raw(f)
                <> ")"
            }
          _ ->
            "  let "
            <> f.label
            <> " = api_help.opt_string_from_db("
            <> raw(f)
            <> ")"
        }
      }
      glance.NamedType(_, "Timestamp", _, []) ->
        "  let "
        <> f.label
        <> " = api_help.timestamp_from_db_unix("
        <> raw(f)
        <> ")"
      _ ->
        "  let "
        <> f.label
        <> " = api_help.opt_string_from_db("
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
      <> ", "
      <> rich_row_data_field_decode_subexpr(f)
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
  let lets = rich_decode_lets(data_fields, ctx)
  let needs_dob_assert =
    list.any(v.fields, fn(f) { type_expr_is_calendar_date(f.type_) })
  let assert_line = case needs_dob_assert {
    True -> "\n  let assert option.Some(dob_identity) = date_of_birth\n"
    False -> ""
  }
  let row_intro = case needs_dob_assert {
    True -> "  let "
    False -> "\n  let "
  }
  let row_local = string.lowercase(entity.type_name)
  let field_lines =
    join_data_and_list_field_lines(
      list.map(data_fields, fn(f) { "      " <> f.label <> ":," })
        |> string.join("\n"),
      entity,
    )
  let ident =
    "      identities: " <> rich_identity_construct_call(v, ctx) <> ","
  let rel = case entity_has_relationships_field(entity) {
    True ->
      "\n      relationships: "
      <> default_relationships_record(schema, entity, ctx)
      <> ","
    False -> ""
  }
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
  <> ctx.schema_alias
  <> "."
  <> entity.type_name
  <> "(\n"
  <> field_lines
  <> "\n"
  <> ident
  <> rel
  <> "\n    )\n  decode.success(#(\n    "
  <> row_local
  <> ",\n    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),\n  ))"
}

pub fn entity_row_tuple_type(ctx: TypeCtx, entity_name: String) -> String {
  "#(" <> ctx.schema_alias <> "." <> entity_name <> ", dsl.MagicFields)"
}

pub fn option_entity_row_tuple(ctx: TypeCtx, entity_name: String) -> String {
  "option.Option(#("
  <> ctx.schema_alias
  <> "."
  <> entity_name
  <> ", dsl.MagicFields))"
}

fn row_decoder_expr_for_named(name: String, ctx: TypeCtx) -> String {
  case name {
    "Int" -> "decode.int"
    "Float" -> "decode.float"
    "String" -> "decode.string"
    "Bool" -> "decode.map(decode.int, fn(i) { i != 0 })"
    "Timestamp" ->
      "decode.map(decode.int, fn(i) { api_help.timestamp_from_db_unix(i) })"
    _ ->
      case list.contains(ctx.enum_scalar_names, name) {
        True ->
          "decode.then(decode.string, fn(s) {\n    case "
          <> scalar_from_db_fn_name(name)
          <> "(s) {\n      option.Some(v) -> decode.success(v)\n      option.None -> decode.failure("
          <> ctx.schema_alias
          <> "."
          <> name
          <> ", expected: \""
          <> name
          <> "\")\n    }\n  })"
        False -> "decode.string"
      }
  }
}

/// Decoders for `Option(Int|Float|Bool)` columns that are not identity keys (nullable in SQLite).
fn row_decoder_expr_optional_primitive_entity_field(
  f: FieldDefinition,
  ctx: TypeCtx,
) -> String {
  case f.type_ {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "Timestamp", _, [])]) ->
      "decode.optional(decode.int)"
    glance.NamedType(_, "Option", _, [glance.NamedType(_, n, _, [])]) ->
      case n {
        "String" -> "decode.optional(decode.string)"
        "Int" -> "decode.optional(decode.int)"
        "Float" -> "decode.optional(decode.float)"
        "Bool" ->
          "decode.optional(decode.map(decode.int, fn(i) { i != 0 }))"
        _ -> row_decoder_expr(f.type_, ctx)
      }
    _ -> row_decoder_expr(f.type_, ctx)
  }
}

/// Identity-key columns must decode as non-null primitives so `ByNameAndAge(name:, age:)` types match.
fn row_decoder_expr_for_entity_data_field(
  f: FieldDefinition,
  identity_labels: List(String),
  ctx: TypeCtx,
) -> String {
  case list.contains(identity_labels, f.label) {
    True ->
      case f.type_ {
        glance.NamedType(_, "Option", _, [glance.NamedType(_, n, _, [])]) ->
          row_decoder_expr_for_named(n, ctx)
        _ -> row_decoder_expr(f.type_, ctx)
      }
    False -> row_decoder_expr_optional_primitive_entity_field(f, ctx)
  }
}

fn row_decoder_expr(field_type: glance.Type, ctx: TypeCtx) -> String {
  case field_type {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "Timestamp", _, [])]) ->
      "decode.map(decode.int, fn(i) { api_help.opt_timestamp_from_db(i) })"
    glance.NamedType(_, "Option", _, [glance.NamedType(_, n, _, [])]) ->
      case
        list.contains(ctx.scalar_names, n),
        list.contains(ctx.enum_scalar_names, n)
      {
        True, False ->
          "decode.then(decode.string, fn(s) {\n    case "
          <> scalar_from_db_fn_name(n)
          <> "(s) {\n      Ok(v) -> decode.success(v)\n      Error(_) -> decode.failure(option.None, expected: \"Option("
          <> n
          <> ")\")\n    }\n  })"
        True, True ->
          "decode.then(decode.string, fn(s) { decode.success("
          <> scalar_from_db_fn_name(n)
          <> "(s) })"
        False, _ -> row_decoder_expr_for_named(n, ctx)
      }
    _ ->
      case field_type {
        glance.NamedType(_, n, _, []) -> row_decoder_expr_for_named(n, ctx)
        _ -> "decode.string"
      }
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

fn field_is_timestamp_option(f: FieldDefinition) -> Bool {
  case f.type_ {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "Timestamp", _, [])]) ->
      True
    _ -> False
  }
}

fn identity_construct_call(v: IdentityVariantDefinition, ctx: TypeCtx) -> String {
  let args =
    list.map(v.fields, fn(f) { f.label <> ":" })
    |> string.join(", ")
  ctx.schema_alias <> "." <> v.variant_name <> "(" <> args <> ")"
}

fn entity_constructor_list_placeholder_lines(entity: EntityDefinition) -> String {
  api_sql.entity_row_list_placeholder_fields(entity)
  |> list.map(fn(f) { "      " <> f.label <> ": []," })
  |> string.join("\n")
}

fn join_data_and_list_field_lines(
  data_lines: String,
  entity: EntityDefinition,
) -> String {
  case entity_constructor_list_placeholder_lines(entity) {
    "" -> data_lines
    list_lines -> data_lines <> "\n" <> list_lines
  }
}

fn is_option_non_enum_scalar_field(f: FieldDefinition, ctx: TypeCtx) -> Bool {
  case f.type_ {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, n, _, [])]) ->
      list.contains(ctx.scalar_names, n)
      && !list.contains(ctx.enum_scalar_names, n)
    _ -> False
  }
}

fn field_to_constructor_arg(
  f: FieldDefinition,
  ids: List(String),
  var: String,
  ctx: TypeCtx,
) -> String {
  let in_id = list.contains(ids, f.label)
  case in_id {
    True ->
      case type_is_option(f.type_) {
        True -> "option.Some(" <> var <> ")"
        False -> var
      }
    False ->
      case
        is_option_non_enum_scalar_field(f, ctx),
        type_is_option(f.type_),
        field_is_timestamp_option(f),
        type_is_option_string(f.type_)
      {
        True, _, _, _ -> var
        False, True, True, _ ->
          "api_help.option_timestamp_from_optional_unix(" <> var <> ")"
        False, True, False, True ->
          "api_help.option_string_from_optional_db(" <> var <> ")"
        False, True, False, False ->
          case f.type_ {
            glance.NamedType(_, "Option", _, [glance.NamedType(_, "Int", _, [])]) ->
              var
            glance.NamedType(_, "Option", _, [glance.NamedType(_, "Float", _, [])]) ->
              var
            glance.NamedType(_, "Option", _, [glance.NamedType(_, "Bool", _, [])]) ->
              var
            _ -> "option.Some(" <> var <> ")"
          }
        False, False, _, _ -> var
      }
  }
}

fn entity_simple_magic_decoder_fn(
  entity: EntityDefinition,
  v: IdentityVariantDefinition,
  ctx: TypeCtx,
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
      <> row_decoder_expr_for_entity_data_field(f, ids, ctx)
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
    join_data_and_list_field_lines(
      list.map(data_fields, fn(f) {
        let var = f.label
        let expr = field_to_constructor_arg(f, ids, var, ctx)
        "      " <> f.label <> ": " <> expr <> ","
      })
        |> string.join("\n"),
      entity,
    )
  let ident = "      identities: " <> identity_construct_call(v, ctx) <> ","
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
  <> ctx.schema_alias
  <> "."
  <> entity.type_name
  <> "(\n"
  <> field_lines
  <> "\n"
  <> ident
  <> "\n    )\n  decode.success(#(\n    "
  <> row_local
  <> ",\n    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),\n  ))"
}

fn entity_with_magic_decoder_fn(
  schema: SchemaDefinition,
  entity: EntityDefinition,
  v: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> String {
  case entity_needs_rich_row_decoder(entity, ctx) {
    True -> entity_rich_row_decoder_fn(schema, entity, v, ctx)
    False -> entity_simple_magic_decoder_fn(entity, v, ctx)
  }
}

pub fn subset_output_appendage(specs: List(QuerySpecDefinition)) -> String {
  api_subset.subset_output_appendage(specs)
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
      gleamgen_emit.pub_def(entity_snake <> "_with_magic_row_decoder"),
      gfun.new_raw(
        [],
        gtypes.raw(
          "decode.Decoder("
          <> entity_row_tuple_type(ctx, entity.type_name)
          <> ")",
        ),
        fn(_) {
          gexpr.raw(entity_with_magic_decoder_fn(schema, entity, variant, ctx))
        },
      )
        |> gfun.to_dynamic,
    ),
  ]
}

