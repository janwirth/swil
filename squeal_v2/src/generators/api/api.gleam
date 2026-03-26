import generators/api/api_chunks
import generators/api/api_decoders as dec
import generators/api/api_imports
import generators/api/api_naming
import generators/api/api_params
import generators/api/api_query
import generators/api/api_sql
import generators/api/schema_context
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/render as grender
import gleamgen/types as gtypes
import schema_definition/query.{LtMissingFieldAsc}
import schema_definition/schema_definition.{type SchemaDefinition}

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

fn build_module(path: String, def: SchemaDefinition) -> gmod.Module {
  let assert [entity, ..] = def.entities
  let ctx = dec.type_ctx(path, def)
  let exposing = schema_context.api_schema_exposing(def, entity)
  let migration_path = schema_context.migration_import_path(path)
  let id = schema_context.find_identity(def, entity)
  let assert Ok(variant) = list.first(id.variants)
  let table = string.lowercase(entity.type_name)
  let data_fields = api_sql.entity_data_fields(entity)
  let data_col_labels = list.map(data_fields, fn(f) { f.label })
  let id_cols = list.map(variant.fields, fn(f) { f.label })
  let returning = api_sql.full_row_columns(data_col_labels)
  let entity_snake = string.lowercase(entity.type_name)
  let id_snake = case string.starts_with(variant.variant_name, "By") {
    True -> api_naming.pascal_to_snake(string.drop_start(variant.variant_name, 2))
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
    list.filter(def.queries, fn(q) { api_query.query_spec_targets_entity(q, entity) })

  let row_t = gtypes.raw(dec.entity_row_tuple_type(entity.type_name))
  let sql_err = gtypes.raw("sqlight.Error")
  let upsert_params =
    list.append([api_params.conn_param()], api_params.upsert_gparams(entity, variant, ctx))
  let get_params = list.append([api_params.conn_param()], api_params.identity_gparams(variant))

  let enum_scalar_names =
    def.scalars
    |> list.filter(fn(s) { s.enum_only })
    |> list.map(fn(s) { s.type_name })

  let fn_chunks =
    list.flatten([
      api_query.generated_query_fn_chunks(
        entity_snake,
        row_t,
        sql_err,
        ctx,
        generated_query_specs,
      ),
      api_chunks.crud_public_fn_chunks(
        entity,
        variant,
        entity_snake,
        id_snake,
        upsert_params,
        get_params,
        row_t,
        sql_err,
        enum_scalar_names,
      ),
      dec.row_decode_helpers_fn_chunks(entity_snake, def, entity, variant, ctx),
      list.flatten([
        api_chunks.scalar_enum_db_fn_chunks(def, entity),
        api_chunks.calendar_date_fn_chunks(path, def),
      ]),
    ])

  let with_functions =
    list.fold(fn_chunks, gmod.eof(), fn(acc, chunk) {
      let #(def_f, fun) = chunk
      gmod.with_function(def_f, fun, fn(_) { acc })
    })

  let query_const_entries =
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
    })

  let const_entries =
    list.append(query_const_entries, [
      #("last_100_sql", Some(last_s)),
      #("soft_delete_by_" <> id_snake <> "_sql", Some(soft_s)),
      #("update_by_" <> id_snake <> "_sql", Some(update_s)),
      #("select_by_" <> id_snake <> "_sql", Some(select_s)),
      #("upsert_sql", Some(upsert_s)),
    ])

  let with_constants =
    list.fold(const_entries, with_functions, fn(acc, entry) {
      let #(name, val_opt) = entry
      case val_opt {
        None -> acc
        Some(v) -> {
          let def_c = gdef.new(name)
          gmod.with_constant(def_c, gexpr.string(v), fn(_) { acc })
        }
      }
    })

  api_imports.with_api_imports(migration_path, path, def, exposing, fn() {
    with_constants
  })
}
