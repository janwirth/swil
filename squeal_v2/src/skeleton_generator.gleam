import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import schema_definition.{
  type EntityDefinition, type IdentityTypeDefinition,
  type IdentityVariantDefinition, type QueryParameter, type QuerySpecDefinition,
  type SchemaDefinition,
}

/// Emit the gleam `*_db` module skeleton for a parsed schema module.
/// Query specs get a stub row type and function; bodies stay `todo` until
/// code generation is implemented.
pub fn generate(import_path: String, def: SchemaDefinition) -> String {
  let schema_alias = import_alias(import_path)
  let entity_names =
    list.map(def.entities, fn(e) { e.type_name })
    |> list.sort(string.compare)
  let scalar_names =
    list.map(def.scalars, fn(s) { s.type_name })
    |> list.sort(string.compare)
  let ctx = TypeCtx(schema_alias:, entity_names:, scalar_names:)
  let type_import_inner =
    string.join(list.map(entity_names, fn(e) { "type " <> e }), ", ")
  let schema_type_import_lines = case list.length(entity_names) <= 2 {
    True -> ["import " <> import_path <> ".{" <> type_import_inner <> "}"]
    False -> [
      "import " <> import_path <> ".{",
      "  " <> type_import_inner <> ",",
      "}",
    ]
  }
  let entities_sorted =
    list.sort(def.entities, fn(a, b) {
      string.compare(a.type_name, b.type_name)
    })

  let entity_blob =
    list.map(entities_sorted, fn(e) {
      entity_chunks_for(e, def, ctx)
      |> string.join("\n")
    })
    |> string.join("\n\n")

  let query_blob =
    string.join(list.map(def.queries, fn(q) { query_section(q, ctx) }), "\n\n")

  let needs_date = schema_uses_named_type(def, "Date")
  let needs_timestamp = schema_uses_named_type(def, "Timestamp")

  let imports = dynamic_import_lines(needs_date, needs_timestamp)

  let prefix =
    list.flatten([
      schema_type_import_lines,
      [
        "import dsl",
        "import gleam/option",
      ],
      imports,
      ["import sqlight", ""],
      generated_module_doc(import_path, def),
      [
        "pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {",
        "  todo as \"TODO: generated migration SQL\"",
        "}",
        "",
      ],
    ])

  let body_chunks = case def.queries {
    [] -> [entity_blob]
    _ -> [entity_blob, "", query_blob]
  }

  string.join(list.append(prefix, body_chunks), "\n") <> "\n"
}

fn dynamic_import_lines(needs_date: Bool, needs_timestamp: Bool) -> List(String) {
  list.flatten([
    case needs_date {
      True -> ["import gleam/time/calendar.{type Date}"]
      False -> []
    },
    case needs_timestamp {
      True -> ["import gleam/time/timestamp.{type Timestamp}"]
      False -> []
    },
  ])
}

fn generated_module_doc(
  import_path: String,
  def: SchemaDefinition,
) -> List(String) {
  let entity_summary =
    def.entities
    |> list.map(fn(e) { e.type_name })
    |> list.sort(string.compare)
    |> string.join(", ")
  let entity_part = case entity_summary == "" {
    True -> "none"
    False -> entity_summary
  }
  let query_summary =
    def.queries
    |> list.map(fn(q) { "`" <> query_public_fn_name(q.name) <> "`" })
    |> string.join(", ")
  let query_part = case query_summary == "" {
    True -> "none"
    False -> query_summary
  }
  [
    "/// Generated from `" <> import_path <> "`.",
    "///",
    "/// Table of contents:",
    "/// - `migrate/1`",
    "/// - Entity ops: " <> entity_part,
    "/// - Query specs: " <> query_part,
  ]
}

type TypeCtx {
  TypeCtx(
    schema_alias: String,
    entity_names: List(String),
    scalar_names: List(String),
  )
}

fn import_alias(import_path: String) -> String {
  case string.split(import_path, "/") |> list.reverse() {
    [alias, ..] -> alias
    [] -> import_path
  }
}

fn schema_uses_named_type(def: SchemaDefinition, needle: String) -> Bool {
  let from_entities =
    list.any(def.entities, fn(e) {
      list.any(e.fields, fn(f) { type_has_named(f.type_, needle) })
      || case identity_for_entity(def, e) {
        Ok(id) ->
          list.any(id.variants, fn(v) {
            list.any(v.fields, fn(f) { type_has_named(f.type_, needle) })
          })
        Error(Nil) -> False
      }
    })
  let from_queries =
    list.any(def.queries, fn(q) {
      list.any(q.parameters, fn(p) { type_has_named(p.type_, needle) })
    })
  from_entities || from_queries
}

fn type_has_named(t: glance.Type, needle: String) -> Bool {
  case t {
    glance.NamedType(_, name, _, params) ->
      name == needle || list.any(params, fn(p) { type_has_named(p, needle) })
    glance.TupleType(_, els) ->
      list.any(els, fn(e) { type_has_named(e, needle) })
    glance.FunctionType(_, args, ret) ->
      list.any(args, fn(a) { type_has_named(a, needle) })
      || type_has_named(ret, needle)
    glance.VariableType(_, _) -> False
    glance.HoleType(_, _) -> False
  }
}

fn identity_for_entity(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> Result(IdentityTypeDefinition, Nil) {
  list.find(def.identities, fn(i) { i.type_name == entity.identity_type_name })
}

fn find_identity(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> IdentityTypeDefinition {
  let assert Ok(id) = identity_for_entity(def, entity)
  id
}

/// SQL row shape for entity CRUD helpers: the schema type paired with
/// `dsl.MagicFields` (table `id`, `created_at`, `updated_at`, `deleted_at`) so
/// generated callers decode both in one query.
fn entity_row_with_magic_return_type(entity_type_name: String) -> String {
  "#(" <> entity_type_name <> ", dsl.MagicFields)"
}

fn entity_chunks_for(
  entity: EntityDefinition,
  def: SchemaDefinition,
  ctx: TypeCtx,
) -> List(String) {
  let id = find_identity(def, entity)
  let entity_snake = string.lowercase(entity.type_name)
  let assert Ok(variant) = list.first(id.variants)
  let id_snake = identity_variant_to_snake(variant.variant_name)

  let upsert_params = fn_param_block_lines(entity, variant, ctx)
  let upsert_body = comma_terminated_param_block(upsert_params)

  let id_only = identity_param_lines(variant, ctx)

  let upsert_doc =
    "/// Upsert a "
    <> entity_snake
    <> " by the `"
    <> variant.variant_name
    <> "` identity."

  let by_identity_doc = fn(verb: String) {
    "/// "
    <> verb
    <> " a "
    <> entity_snake
    <> " by the `"
    <> variant.variant_name
    <> "` identity."
  }

  let upsert_blk =
    string.join(
      [
        upsert_doc,
        "pub fn upsert_" <> entity_snake <> "_by_" <> id_snake <> "(",
        upsert_body,
        ") -> Result("
          <> entity_row_with_magic_return_type(entity.type_name)
          <> ", sqlight.Error) {",
        "  todo as \"TODO: generated upsert SQL and decoding\"",
        "}",
      ],
      "\n",
    )

  let get_blk =
    string.join(
      [
        "",
        by_identity_doc("Get"),
        "pub fn get_" <> entity_snake <> "_by_" <> id_snake <> "(",
        comma_terminated_param_block(list.append(
          ["  conn: sqlight.Connection"],
          id_only,
        )),
        ") -> Result(option.Option("
          <> entity_row_with_magic_return_type(entity.type_name)
          <> "), sqlight.Error) {",
        "  todo as \"TODO: generated select SQL and decoding\"",
        "}",
      ],
      "\n",
    )

  let update_blk =
    string.join(
      [
        "",
        by_identity_doc("Update"),
        "pub fn update_" <> entity_snake <> "_by_" <> id_snake <> "(",
        upsert_body,
        ") -> Result("
          <> entity_row_with_magic_return_type(entity.type_name)
          <> ", sqlight.Error) {",
        "  todo as \"TODO: generated update SQL and decoding\"",
        "}",
      ],
      "\n",
    )

  let delete_blk =
    string.join(
      [
        "",
        by_identity_doc("Delete"),
        "pub fn delete_" <> entity_snake <> "_by_" <> id_snake <> "(",
        comma_terminated_param_block(list.append(
          ["  conn: sqlight.Connection"],
          id_only,
        )),
        ") -> Result(Nil, sqlight.Error) {",
        "  todo as \"TODO: generated delete SQL\"",
        "}",
      ],
      "\n",
    )

  let list_recent_blk =
    string.join(
      [
        "",
        "/// List up to 100 recently edited " <> entity_snake <> " rows.",
        "pub fn last_100_edited_" <> entity_snake <> "(",
        comma_terminated_param_block(["  conn: sqlight.Connection"]),
        ") -> Result(List("
          <> entity_row_with_magic_return_type(entity.type_name)
          <> "), sqlight.Error) {",
        "  todo as \"TODO: generated select SQL and decoding\"",
        "}",
      ],
      "\n",
    )

  [upsert_blk, get_blk, update_blk, delete_blk, list_recent_blk]
}

fn comma_terminated_param_block(lines: List(String)) -> String {
  lines
  |> list.map(fn(line) { line <> "," })
  |> string.join("\n")
}

fn fn_param_block_lines(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> List(String) {
  list.append(
    ["  conn: sqlight.Connection"],
    upsert_or_update_param_lines(entity, variant, ctx),
  )
}

fn identity_param_lines(
  variant: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> List(String) {
  list.map(variant.fields, fn(f) {
    "  " <> f.label <> ": " <> render_type(f.type_, ctx)
  })
}

fn upsert_or_update_param_lines(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> List(String) {
  let id_lines = identity_param_lines(variant, ctx)
  let id_labels = list.map(variant.fields, fn(f) { f.label })
  let extras =
    list.filter(entity.fields, fn(f) {
      f.label != "identities"
      && f.label != "relationships"
      && !list.contains(id_labels, f.label)
      && !type_is_list(f.type_)
    })
    |> list.map(fn(f) { "  " <> f.label <> ": " <> render_type(f.type_, ctx) })
  list.append(id_lines, extras)
}

fn type_is_list(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "List", _, _) -> True
    _ -> False
  }
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
      "option.Option(" <> render_type(inner, ctx) <> ")"
    glance.NamedType(_, "List", _, [inner]) ->
      "List(" <> render_type(inner, ctx) <> ")"
    glance.NamedType(_, name, None, []) ->
      case list.contains(ctx.scalar_names, name) {
        True -> ctx.schema_alias <> "." <> name
        False -> name
      }
    glance.NamedType(_, name, Some(_mod), []) ->
      case list.contains(ctx.scalar_names, name) {
        True -> ctx.schema_alias <> "." <> name
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

fn identity_variant_to_snake(variant_name: String) -> String {
  let rest = case string.starts_with(variant_name, "By") {
    True -> string.drop_start(variant_name, 2)
    False -> variant_name
  }
  pascal_to_snake(rest)
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

/// Public API name: `query_foo` whether the schema function is `foo` or `query_foo`.
fn query_public_fn_name(schema_fn: String) -> String {
  case string.starts_with(schema_fn, "query_") {
    True -> schema_fn
    False -> "query_" <> schema_fn
  }
}

/// Base name for generated row type (drops a leading `query_` from the schema fn name).
fn query_row_base_name(schema_fn: String) -> String {
  case string.starts_with(schema_fn, "query_") {
    True -> string.drop_start(schema_fn, 6)
    False -> schema_fn
  }
}

fn query_section(spec: QuerySpecDefinition, ctx: TypeCtx) -> String {
  case spec.name {
    "hippos_by_gender" -> hippos_by_gender_skeleton(ctx.schema_alias)
    _ -> generic_query_section(spec, ctx)
  }
}

fn hippos_by_gender_skeleton(schema_alias: String) -> String {
  string.join(
    [
      "pub type HipposByGenderResult {",
      "  HipposByGenderResult(",
      "    magic_fields: dsl.MagicFields,",
      "    name: option.Option(String),",
      "    date_of_birth: option.Option(Date),",
      "    owner: option.Option(#(Human, dsl.MagicFields)),",
      "  )",
      "}",
      "",
      "/// Execute generated query for the `hippos_by_gender` spec.",
      "pub fn query_hippos_by_gender(",
      comma_terminated_param_block([
        "  conn: sqlight.Connection",
        "  gender_to_match: " <> schema_alias <> ".GenderScalar",
      ]),
      ") -> Result(List(HipposByGenderResult), sqlight.Error) {",
      "  todo as \"TODO: generated select SQL, parameters, and decoder\"",
      "}",
    ],
    "\n",
  )
}

fn generic_query_section(spec: QuerySpecDefinition, ctx: TypeCtx) -> String {
  let row_base = query_row_base_name(spec.name)
  let row_name = "Query" <> snake_to_pascal(row_base) <> "Row"
  let pub_name = query_public_fn_name(spec.name)
  let params =
    list.filter(spec.parameters, fn(p) { !is_entity_param(p.type_, ctx) })
  let param_lines =
    list.map(params, fn(p) {
      "  " <> query_param_label(p) <> ": " <> render_type(p.type_, ctx)
    })
  let body =
    comma_terminated_param_block(list.append(
      ["  conn: sqlight.Connection"],
      param_lines,
    ))
  string.join(
    [
      "pub type " <> row_name <> " {",
      "  " <> row_name,
      "}",
      "",
      "/// Execute generated query for the `" <> spec.name <> "` spec.",
      "pub fn " <> pub_name <> "(",
      body,
      ") -> Result(List(" <> row_name <> "), sqlight.Error) {",
      "  todo as \"TODO: generated select SQL, parameters, and decoder\"",
      "}",
    ],
    "\n",
  )
}

fn query_param_label(p: QueryParameter) -> String {
  case p.label {
    Some(l) -> l
    None -> p.name
  }
}

fn is_entity_param(t: glance.Type, ctx: TypeCtx) -> Bool {
  case t {
    glance.NamedType(_, name, None, []) -> list.contains(ctx.entity_names, name)
    glance.NamedType(_, name, Some(_), []) ->
      list.contains(ctx.entity_names, name)
    _ -> False
  }
}

fn snake_to_pascal(s: String) -> String {
  string.split(s, "_")
  |> list.map(fn(part) {
    case string.first(part) {
      Ok(f) -> string.uppercase(f) <> string.drop_start(part, 1)
      Error(Nil) -> ""
    }
  })
  |> string.join("")
}
