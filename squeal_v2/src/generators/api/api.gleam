import generators/api/api_chunks
import generators/api/api_decoders as dec
import generators/api/api_facade as facade
import generators/api/api_imports
import generators/api/api_naming
import generators/api/api_params
import generators/api/api_query
import generators/api/api_sql
import generators/api/api_update_delete as ud
import generators/api/schema_context
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/render as grender
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type SchemaDefinition, LtMissingFieldAsc,
}

pub type ApiDbOutputs {
  ApiDbOutputs(
    row: String,
    upsert: String,
    delete: String,
    query: String,
    api: String,
  )
}

fn finalize_string(s: String) -> String {
  case string.ends_with(s, "\n") {
    True -> s
    False -> s <> "\n"
  }
}

/// gleamgen drops `import api_help` when the module body only references `api_help` via raw strings.
fn ensure_api_help_import(text: String) -> String {
  case
    string.contains(text, "api_help.")
    && !string.contains(text, "import api_help")
  {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport api_help\n" <> string.join(rest, "\n")
      }
    }
  }
}

/// gleamgen may omit `dsl` when return types only use `dsl.` inside raw strings.
fn ensure_dsl_import(text: String) -> String {
  case string.contains(text, "dsl.") && !string.contains(text, "dsl/dsl") {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport dsl/dsl as dsl\n" <> string.join(rest, "\n")
      }
    }
  }
}

/// gleamgen may omit `gleam/option` when signatures use `Option(...)` only via raw types.
fn ensure_option_import(text: String) -> String {
  case
    string.contains(text, "Option(")
    && !string.contains(text, "import gleam/option")
  {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first
          <> "\nimport gleam/option.{type Option, None, Some}\n"
          <> string.join(rest, "\n")
      }
    }
  }
}

fn render_module(m: gmod.Module) -> String {
  m
  |> gmod.render(grender.default_context())
  |> grender.to_string()
  |> finalize_string
}

fn fold_fn_chunks(
  chunks: List(
    #(gdef.Definition, gfun.Function(gtypes.Dynamic, gtypes.Dynamic)),
  ),
  start: gmod.Module,
) -> gmod.Module {
  list.fold(chunks, start, fn(acc, chunk) {
    let #(def_f, fun) = chunk
    gmod.with_function(def_f, fun, fn(_) { acc })
  })
}

fn fold_constants(
  entries: List(#(String, Option(String))),
  start: gmod.Module,
) -> gmod.Module {
  list.fold(entries, start, fn(acc, entry) {
    let #(name, val_opt) = entry
    case val_opt {
      None -> acc
      Some(v) -> {
        let def_c = gdef.new(name)
        gmod.with_constant(def_c, gexpr.string(v), fn(_) { acc })
      }
    }
  })
}

/// Emits `row`, `upsert`, `delete`, `query`, and `api` (facade) modules under `*_db/`.
pub fn generate_api_db_outputs(
  schema_path: String,
  def: SchemaDefinition,
) -> ApiDbOutputs {
  let assert [entity, ..] = def.entities
  let ctx = dec.type_ctx(schema_path, def)
  let exposing = schema_context.api_schema_exposing(def, entity)
  let migration_path = schema_context.migration_import_path(schema_path)
  let db_path = schema_context.db_module_path_from_schema(schema_path)
  let id = schema_context.find_identity(def, entity)
  let assert Ok(variant) = list.first(id.variants)
  let table = string.lowercase(entity.type_name)
  let data_fields = api_sql.entity_data_fields(entity)
  let data_col_labels = list.map(data_fields, fn(f) { f.label })
  let id_cols = list.map(variant.fields, fn(f) { f.label })
  let returning = api_sql.full_row_columns(data_col_labels)
  let entity_snake = string.lowercase(entity.type_name)
  let id_snake = case string.starts_with(variant.variant_name, "By") {
    True ->
      api_naming.pascal_to_snake(string.drop_start(variant.variant_name, 2))
    False -> api_naming.pascal_to_snake(variant.variant_name)
  }
  let upsert_s = api_sql.upsert_sql(table, data_col_labels, id_cols, returning)
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

  let generated_query_specs =
    list.filter(def.queries, fn(q) {
      api_query.query_spec_targets_entity(q, entity)
    })

  let row_t = gtypes.raw(dec.entity_row_tuple_type(entity.type_name))
  let sql_err = gtypes.raw("sqlight.Error")
  let upsert_params =
    list.append(
      [api_params.conn_param()],
      api_params.upsert_gparams(entity, variant, ctx),
    )
  let get_params =
    list.append([api_params.conn_param()], api_params.identity_gparams(variant))

  let enum_scalar_names =
    def.scalars
    |> list.filter(fn(s) { s.enum_only })
    |> list.map(fn(s) { s.type_name })

  let row_chunks =
    api_chunks.row_module_fn_chunks(def, entity_snake, entity, variant, ctx)

  let row_mod =
    api_imports.with_row_module_imports(
      db_path,
      schema_path,
      def,
      exposing,
      fn() { fold_fn_chunks(row_chunks, gmod.eof()) },
    )

  let upsert_const_entries = [
    #("update_by_" <> id_snake <> "_sql", Some(update_s)),
    #("select_by_" <> id_snake <> "_sql", Some(select_s)),
    #("upsert_sql", Some(upsert_s)),
  ]
  let upsert_fn_chunks =
    api_chunks.upsert_module_fn_chunks(
      entity,
      variant,
      entity_snake,
      id_snake,
      upsert_params,
      get_params,
      row_t,
      sql_err,
      enum_scalar_names,
    )
  let upsert_mod =
    api_imports.with_upsert_module_imports(
      db_path,
      schema_path,
      def,
      exposing,
      fn() {
        upsert_const_entries
        |> fold_constants(fold_fn_chunks(upsert_fn_chunks, gmod.eof()))
      },
    )

  let delete_const_entries = [
    #("soft_delete_by_" <> id_snake <> "_sql", Some(soft_s)),
  ]
  let delete_fn_chunks = [
    api_chunks.not_found_private_chunk(entity_snake),
    ud.delete_fn_chunk(entity_snake, id_snake, variant, get_params, sql_err),
  ]
  let delete_mod =
    api_imports.with_delete_module_imports(
      db_path,
      schema_path,
      def,
      exposing,
      fn() {
        delete_const_entries
        |> fold_constants(fold_fn_chunks(delete_fn_chunks, gmod.eof()))
      },
    )

  let query_const_entries =
    list.append(
      [#("last_100_sql", Some(last_s))],
      list.map(generated_query_specs, fn(spec) {
        let assert LtMissingFieldAsc(
          column: column,
          threshold_param: _,
          shape_param: _,
        ) = spec.codegen
        #(
          api_query.query_sql_const_name(spec.name),
          Some(api_sql.lt_column_asc_sql(table, returning, column)),
        )
      }),
    )
  let query_fn_chunks =
    api_chunks.query_module_fn_chunks(
      entity_snake,
      row_t,
      sql_err,
      ctx,
      generated_query_specs,
    )
  let query_mod =
    api_imports.with_query_module_imports(
      db_path,
      schema_path,
      def,
      exposing,
      fn() {
        query_const_entries
        |> fold_constants(fold_fn_chunks(query_fn_chunks, gmod.eof()))
      },
    )

  let facade_chunks =
    facade.facade_fn_chunks(
      def,
      entity,
      variant,
      entity_snake,
      id_snake,
      upsert_params,
      get_params,
      row_t,
      sql_err,
      ctx,
      generated_query_specs,
    )
  let api_mod =
    api_imports.with_facade_module_imports(
      migration_path,
      db_path,
      schema_path,
      def,
      exposing,
      fn() { fold_fn_chunks(facade_chunks, gmod.eof()) },
    )

  ApiDbOutputs(
    row: render_module(row_mod) |> ensure_dsl_import,
    upsert: ensure_dsl_import(render_module(upsert_mod)),
    delete: ensure_api_help_import(render_module(delete_mod)),
    query: ensure_dsl_import(render_module(query_mod)),
    api: render_module(api_mod)
      |> ensure_option_import
      |> ensure_dsl_import,
  )
}

/// Backwards-compatible: returns only the `api.gleam` facade source.
pub fn generate_api(schema_path: String, schema: SchemaDefinition) -> String {
  generate_api_db_outputs(schema_path, schema).api
}
