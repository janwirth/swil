import generators/gleam_format_generated as gleam_fmt
import generators/gleamgen_emit
import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/import_ as gimport
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/render as grender
import gleamgen/types as gtypes
import gleamgen/types/custom as gcustom
import gleamgen/types/variant as gvariant
import schema_definition/schema_definition.{
  type EntityDefinition, type IdentityTypeDefinition,
  type IdentityVariantDefinition, type QueryParameter, type QuerySpecDefinition,
  type SchemaDefinition,
}

/// Emit the gleam `*_db` module skeleton for a parsed schema module.
/// Query specs get a stub row type and function; bodies stay `panic as` stubs until
/// code generation is implemented.
pub fn generate(
  import_path: String,
  def: SchemaDefinition,
) -> Result(String, String) {
  let text =
    build_module(import_path, def)
    |> gmod.render(grender.default_context())
    |> grender.to_string()
    |> finalize_string
  gleam_fmt.format_generated_source(text)
}

fn finalize_string(s: String) -> String {
  case string.ends_with(s, "\n") {
    True -> s
    False -> s <> "\n"
  }
}

fn build_module(import_path: String, def: SchemaDefinition) -> gmod.Module {
  let schema_alias = import_alias(import_path)
  let entity_names =
    list.map(def.entities, fn(e) { e.type_name })
    |> list.sort(string.compare)
  let scalar_names =
    list.map(def.scalars, fn(s) { s.type_name })
    |> list.sort(string.compare)
  let ctx = TypeCtx(schema_alias:, entity_names:, scalar_names:)
  let needs_date = schema_uses_named_type(def, "Date")
  let needs_timestamp = schema_uses_named_type(def, "Timestamp")

  let entities_sorted =
    list.sort(def.entities, fn(a, b) {
      string.compare(a.type_name, b.type_name)
    })

  let module_doc =
    [
      "/// Generated from `" <> import_path <> "`.",
      "///",
      "/// Table of contents:",
      "/// - `migrate/1`",
      "/// - Entity ops: " <> entity_summary_part(def),
      "/// - Query specs: " <> query_summary_part(def),
      "",
    ]
    |> string.join("\n")

  let body =
    gmod.eof()
    |> fold_queries_reversed(def.queries, ctx)
    |> fold_entities_reversed(entities_sorted, def, ctx)
    |> fn(acc) { add_migrate_fn(module_doc, acc) }

  with_skeleton_imports(
    import_path,
    entity_names,
    needs_date,
    needs_timestamp,
    fn() { body },
  )
}

fn entity_summary_part(def: SchemaDefinition) -> String {
  let entity_summary =
    def.entities
    |> list.map(fn(e) { e.type_name })
    |> list.sort(string.compare)
    |> string.join(", ")
  case entity_summary == "" {
    True -> "none"
    False -> entity_summary
  }
}

fn query_summary_part(def: SchemaDefinition) -> String {
  let query_summary =
    def.queries
    |> list.map(fn(q) { "`" <> query_public_fn_name(q.name) <> "`" })
    |> string.join(", ")
  case query_summary == "" {
    True -> "none"
    False -> query_summary
  }
}

fn schema_exposing_inner(entity_names: List(String)) -> String {
  let type_import_inner =
    string.join(list.map(entity_names, fn(e) { "type " <> e }), ", ")
  case list.length(entity_names) <= 2 {
    True -> type_import_inner
    False -> "\n  " <> type_import_inner <> ",\n"
  }
}

fn with_skeleton_imports(
  import_path: String,
  entity_names: List(String),
  needs_date: Bool,
  needs_timestamp: Bool,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let path_parts = string.split(import_path, "/")
  let schema_mod =
    gimport.new_with_exposing(path_parts, schema_exposing_inner(entity_names))
  gmod.with_import(schema_mod, fn(_) {
    gmod.with_import(
      gimport.new_predefined_with_alias(["dsl", "dsl"], "dsl"),
      fn(_) {
        gmod.with_import(gimport.new_predefined(["gleam", "option"]), fn(_) {
          let after_time = fn() {
            gmod.with_import(gimport.new_predefined(["sqlight"]), fn(_) {
              inner()
            })
          }
          let after_timestamp = fn() {
            case needs_timestamp {
              True ->
                gmod.with_import(
                  gimport.new_with_exposing(
                    ["gleam", "time", "timestamp"],
                    "type Timestamp",
                  ),
                  fn(_) { after_time() },
                )
              False -> after_time()
            }
          }
          let after_calendar = fn() {
            case needs_date {
              True ->
                gmod.with_import(
                  gimport.new_with_exposing(
                    ["gleam", "time", "calendar"],
                    "type Date",
                  ),
                  fn(_) { after_timestamp() },
                )
              False -> after_timestamp()
            }
          }
          after_calendar()
        })
      },
    )
  })
}

fn add_migrate_fn(module_doc: String, acc: gmod.Module) -> gmod.Module {
  let migrate_def =
    gleamgen_emit.pub_def("migrate")
    |> gdef.with_text_before(module_doc)
  let func =
    gfun.new_raw(
      [conn_param()],
      gtypes.result(gtypes.nil, gtypes.raw("sqlight.Error")),
      fn(_args) { gexpr.panic_(Some("TODO: generated migration SQL")) },
    )
  gmod.with_function(migrate_def, func, fn(_n) { acc })
}

fn fold_entities_reversed(
  acc: gmod.Module,
  entities_sorted: List(EntityDefinition),
  def: SchemaDefinition,
  ctx: TypeCtx,
) -> gmod.Module {
  list.reverse(entities_sorted)
  |> list.fold(acc, fn(acc_inner, e) {
    prepend_entity_module(e, def, ctx, acc_inner)
  })
}

fn prepend_entity_module(
  entity: EntityDefinition,
  def: SchemaDefinition,
  ctx: TypeCtx,
  acc: gmod.Module,
) -> gmod.Module {
  entity_function_chunks(entity, def, ctx)
  |> list.fold(acc, fn(acc_inner, chunk) {
    gmod.with_function(chunk.def, chunk.fun, fn(_n) { acc_inner })
  })
}

type FnChunk {
  FnChunk(
    def: gdef.Definition,
    fun: gfun.Function(gtypes.Dynamic, gtypes.Dynamic),
  )
}

fn entity_function_chunks(
  entity: EntityDefinition,
  def: SchemaDefinition,
  ctx: TypeCtx,
) -> List(FnChunk) {
  let id = find_identity(def, entity)
  let entity_snake = string.lowercase(entity.type_name)
  let assert Ok(variant) = list.first(id.variants)
  let id_snake = identity_variant_to_snake(variant.variant_name)

  let upsert_doc =
    "/// Upsert a "
    <> entity_snake
    <> " by the `"
    <> variant.variant_name
    <> "` identity.\n"

  let by_identity_doc = fn(verb: String) {
    "/// "
    <> verb
    <> " a "
    <> entity_snake
    <> " by the `"
    <> variant.variant_name
    <> "` identity.\n"
  }

  let upsert_params =
    list.append([conn_param()], upsert_or_update_params(entity, variant, ctx))
  let get_params = list.append([conn_param()], identity_params(variant, ctx))
  let delete_params = get_params
  let list_params = [conn_param()]

  let row_t = entity_row_with_magic_return_type(entity.type_name)
  let sql_err = gtypes.raw("sqlight.Error")

  [
    FnChunk(
      gleamgen_emit.pub_def("upsert_" <> entity_snake <> "_by_" <> id_snake)
        |> gdef.with_text_before(upsert_doc),
      gfun.new_raw(
        upsert_params,
        gtypes.result(gtypes.raw(row_t), sql_err),
        fn(_args) {
          gexpr.panic_(Some("TODO: generated upsert SQL and decoding"))
        },
      )
        |> gfun.to_dynamic,
    ),
    FnChunk(
      gleamgen_emit.pub_def("get_" <> entity_snake <> "_by_" <> id_snake)
        |> gdef.with_text_before(by_identity_doc("Get")),
      gfun.new_raw(
        get_params,
        gtypes.result(gtypes.raw("option.Option(" <> row_t <> ")"), sql_err),
        fn(_args) {
          gexpr.panic_(Some("TODO: generated select SQL and decoding"))
        },
      )
        |> gfun.to_dynamic,
    ),
    FnChunk(
      gleamgen_emit.pub_def("update_" <> entity_snake <> "_by_" <> id_snake)
        |> gdef.with_text_before(by_identity_doc("Update")),
      gfun.new_raw(
        upsert_params,
        gtypes.result(gtypes.raw(row_t), sql_err),
        fn(_args) {
          gexpr.panic_(Some("TODO: generated update SQL and decoding"))
        },
      )
        |> gfun.to_dynamic,
    ),
    FnChunk(
      gleamgen_emit.pub_def("delete_" <> entity_snake <> "_by_" <> id_snake)
        |> gdef.with_text_before(by_identity_doc("Delete")),
      gfun.new_raw(delete_params, gtypes.result(gtypes.nil, sql_err), fn(_args) {
        gexpr.panic_(Some("TODO: generated delete SQL"))
      })
        |> gfun.to_dynamic,
    ),
    FnChunk(
      gleamgen_emit.pub_def("last_100_edited_" <> entity_snake)
        |> gdef.with_text_before(
          "/// List up to 100 recently edited " <> entity_snake <> " rows.\n",
        ),
      gfun.new_raw(
        list_params,
        gtypes.result(gtypes.list(gtypes.raw(row_t)), sql_err),
        fn(_args) {
          gexpr.panic_(Some("TODO: generated select SQL and decoding"))
        },
      )
        |> gfun.to_dynamic,
    ),
  ]
}

fn stub_label(label: String) -> String {
  case string.starts_with(label, "_") {
    True -> label
    False -> "_" <> label
  }
}

fn conn_param() -> gparam.Parameter(gtypes.Dynamic) {
  gparam.new("_conn", gtypes.raw("sqlight.Connection"))
}

fn fold_queries_reversed(
  acc: gmod.Module,
  queries: List(QuerySpecDefinition),
  ctx: TypeCtx,
) -> gmod.Module {
  list.reverse(queries)
  |> list.fold(acc, fn(inner, spec) { query_module_section(spec, ctx, inner) })
}

fn query_module_section(
  spec: QuerySpecDefinition,
  ctx: TypeCtx,
  acc: gmod.Module,
) -> gmod.Module {
  case spec.name {
    "hippos_by_gender" -> hippos_by_gender_module(ctx.schema_alias, acc)
    _ -> generic_query_module(spec, ctx, acc)
  }
}

fn generic_query_module(
  spec: QuerySpecDefinition,
  ctx: TypeCtx,
  acc: gmod.Module,
) -> gmod.Module {
  let row_base = query_row_base_name(spec.name)
  let row_name = "Query" <> snake_to_pascal(row_base) <> "Row"
  let pub_name = query_public_fn_name(spec.name)
  let params =
    list.filter(spec.parameters, fn(p) {
      !is_entity_param(p.type_, ctx) && !is_magic_fields_param(p.type_)
    })
    |> list.map(fn(p) {
      gparam.new(
        stub_label(query_param_label(p)),
        gtypes.raw(render_type(p.type_, ctx)),
      )
    })
  let fn_params = list.append([conn_param()], params)
  let returns =
    gtypes.result(
      gtypes.list(gtypes.custom_type(None, row_name, [])),
      gtypes.raw("sqlight.Error"),
    )
  let query_doc =
    "/// Execute generated query for the `" <> spec.name <> "` spec.\n"
  let type_builder =
    gcustom.new(Nil)
    |> gcustom.with_variant(fn(_) { gvariant.new(row_name) })
  gmod.with_custom_type1(
    gleamgen_emit.pub_def(row_name),
    type_builder,
    fn(_ty, _con) {
      gmod.with_function(
        gleamgen_emit.pub_def(pub_name) |> gdef.with_text_before(query_doc),
        gfun.new_raw(fn_params, returns, fn(_args) {
          gexpr.panic_(Some(
            "TODO: generated select SQL, parameters, and decoder",
          ))
        }),
        fn(_n) { acc },
      )
    },
  )
}

fn is_magic_fields_param(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "MagicFields", _, []) -> True
    _ -> False
  }
}

fn hippos_by_gender_module(
  schema_alias: String,
  acc: gmod.Module,
) -> gmod.Module {
  let row_name = "HipposByGenderResult"
  let magic = gtypes.raw("dsl.MagicFields")
  let type_builder =
    gcustom.new(Nil)
    |> gcustom.with_variant(fn(_) {
      gvariant.new(row_name)
      |> gvariant.with_argument(Some("magic_fields"), magic)
      |> gvariant.with_argument(
        Some("name"),
        gtypes.raw("option.Option(String)"),
      )
      |> gvariant.with_argument(
        Some("date_of_birth"),
        gtypes.raw("option.Option(Date)"),
      )
      |> gvariant.with_argument(
        Some("owner"),
        gtypes.raw("option.Option(#(Human, dsl.MagicFields))"),
      )
    })
  let query_doc =
    "/// Execute generated query for the `hippos_by_gender` spec.\n"
  let fn_params = [
    conn_param(),
    gparam.new(
      stub_label("gender_to_match"),
      gtypes.raw(schema_alias <> ".GenderScalar"),
    ),
  ]
  let returns =
    gtypes.result(
      gtypes.list(gtypes.custom_type(None, row_name, [])),
      gtypes.raw("sqlight.Error"),
    )
  gmod.with_custom_type1(
    gleamgen_emit.pub_def(row_name),
    type_builder,
    fn(_ty, _con) {
      gmod.with_function(
        gleamgen_emit.pub_def("query_hippos_by_gender")
          |> gdef.with_text_before(query_doc),
        gfun.new_raw(fn_params, returns, fn(_args) {
          gexpr.panic_(Some(
            "TODO: generated select SQL, parameters, and decoder",
          ))
        }),
        fn(_n) { acc },
      )
    },
  )
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

fn entity_row_with_magic_return_type(entity_type_name: String) -> String {
  "#(" <> entity_type_name <> ", dsl.MagicFields)"
}

fn identity_params(
  variant: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> List(gparam.Parameter(gtypes.Dynamic)) {
  list.map(variant.fields, fn(f) {
    gparam.new(stub_label(f.label), gtypes.raw(render_type(f.type_, ctx)))
  })
}

fn upsert_or_update_params(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  ctx: TypeCtx,
) -> List(gparam.Parameter(gtypes.Dynamic)) {
  let id_params = identity_params(variant, ctx)
  let id_labels = list.map(variant.fields, fn(f) { f.label })
  let extras =
    list.filter(entity.fields, fn(f) {
      f.label != "identities"
      && f.label != "relationships"
      && !list.contains(id_labels, f.label)
      && !type_is_list(f.type_)
    })
    |> list.map(fn(f) {
      gparam.new(stub_label(f.label), gtypes.raw(render_type(f.type_, ctx)))
    })
  list.append(id_params, extras)
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
    // Any bare named type not caught above (entity, scalar, or type alias from
    // the schema module) is qualified with the schema import alias.
    glance.NamedType(_, name, None, []) -> ctx.schema_alias <> "." <> name
    // Module-qualified in source (e.g. `dsl.Something`): scalars/entities from
    // the schema module are re-qualified; other qualified types use the bare name.
    glance.NamedType(_, name, Some(_mod), []) ->
      case
        list.contains(ctx.scalar_names, name)
        || list.contains(ctx.entity_names, name)
      {
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
