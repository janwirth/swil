import generators/api/api_cmd
import generators/api/api_chunks
import generators/api/api_decoders as dec
import generators/api/api_facade as facade
import generators/api/api_imports
import generators/api/api_naming
import generators/api/api_params
import generators/api/api_query
import generators/api/api_sql
import generators/api/complex_filter_sql
import generators/api/schema_context
import generators/gleam_format_generated as gleam_fmt
import generators/migration/migration as pragma_migration
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/render as grender
import gleamgen/types as gtypes
import schema_definition/predicate_parser
import schema_definition/schema_definition.{
  type Query, type SchemaDefinition, AgeFn, Call, Compare, ComplexRecursive,
  CustomOrder, Eq, ExcludeIfMissing, ExcludeIfMissingFn, Field, Ge, Gt, Le, Lt,
  Ne, NoneOrBase, NullableFn, Param, Predicate, Query, ShapeField, Subset,
}
import swil/dsl

fn quote_ident(s: String) -> String {
  "\"" <> s <> "\""
}

fn expr_needs_owner_join(expr) -> Bool {
  case expr {
    Field(path: [_entity, "relationships", "owner", "item", _]) -> True
    Call(func: _, args: args) -> list.any(args, expr_needs_owner_join)
    _ -> False
  }
}

fn expr_to_sql(expr, table_alias: String) -> Result(String, Nil) {
  case expr {
    Field(path: [_entity, col]) ->
      case table_alias == "" {
        True -> Ok(quote_ident(col))
        False -> Ok(quote_ident(table_alias) <> "." <> quote_ident(col))
      }
    Field(path: [_entity, "relationships", "owner", "item", col]) ->
      Ok("\"hu\"." <> quote_ident(col))
    Call(func: ExcludeIfMissingFn, args: [inner]) ->
      expr_to_sql(inner, table_alias)
    Call(func: NullableFn, args: [inner]) -> expr_to_sql(inner, table_alias)
    Call(func: AgeFn, args: [inner]) ->
      case expr_to_sql(inner, table_alias) {
        Ok(inner_sql) ->
          Ok(
            "cast((julianday('now') - julianday("
            <> inner_sql
            <> ")) / 365.25 as int)",
          )
        Error(Nil) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn operator_sql(op) -> Result(String, Nil) {
  case op {
    Eq -> Ok("=")
    Lt -> Ok("<")
    Gt -> Ok(">")
    Le -> Ok("<=")
    Ge -> Ok(">=")
    Ne -> Ok("!=")
  }
}

fn custom_query_sql(
  table: String,
  returning_cols: List(String),
  query: Query,
) -> Option(String) {
  case query {
    Query(
      shape: query_shape,
      filter: Some(Predicate(Compare(
        left: left_expr,
        operator: operator,
        right: Param(name: _),
        missing_behavior: ExcludeIfMissing,
      ))),
      order: CustomOrder(expr: order_expr, direction: direction),
      ..,
    ) -> {
      let shape_needs_join = case query_shape {
        NoneOrBase -> False
        Subset(selection) ->
          list.any(selection, fn(item) {
            let ShapeField(expr: e, ..) = item
            expr_needs_owner_join(e)
          })
      }
      let use_owner_join =
        expr_needs_owner_join(left_expr)
        || expr_needs_owner_join(order_expr)
        || shape_needs_join
      let base_alias = case use_owner_join {
        True -> "h"
        False -> ""
      }
      let select_cols_result = case query_shape {
        NoneOrBase ->
          Ok(case use_owner_join {
            True ->
              returning_cols
              |> list.map(fn(c) { "\"h\"." <> quote_ident(c) })
              |> string.join(", ")
            False ->
              returning_cols
              |> list.map(quote_ident)
              |> string.join(", ")
          })
        Subset(selection) ->
          list.try_map(selection, fn(item) {
            let ShapeField(expr: e, ..) = item
            expr_to_sql(e, base_alias)
          })
          |> result.map(string.join(_, ", "))
      }
      case
        select_cols_result,
        expr_to_sql(left_expr, base_alias),
        expr_to_sql(order_expr, base_alias),
        operator_sql(operator)
      {
        Ok(select_cols), Ok(left_sql), Ok(order_sql), Ok(op_sql) -> {
          let order_dir = case direction == dsl.Desc {
            True -> " desc"
            False -> " asc"
          }
          let join_sql = case use_owner_join {
            True ->
              "\nleft join \"human\" \"hu\" on \"h\".\"owner_human_id\" = \"hu\".\"id\" and \"hu\".\"deleted_at\" is null"
            False -> ""
          }
          Some(
            "select "
            <> select_cols
            <> " from "
            <> quote_ident(table)
            <> case use_owner_join {
              True -> " \"h\""
              False -> ""
            }
            <> join_sql
            <> " where "
            <> case use_owner_join {
              True -> "\"h\".\"deleted_at\""
              False -> quote_ident("deleted_at")
            }
            <> " is null and "
            <> left_sql
            <> " "
            <> op_sql
            <> " ? order by "
            <> order_sql
            <> order_dir
            <> ";",
          )
        }
        _, _, _, _ -> None
      }
    }
    _ -> None
  }
}

pub type ApiDbOutputs {
  ApiDbOutputs(row: String, get: String, query: String, api: String, cmd: String)
}

fn finalize_string(s: String) -> String {
  case string.ends_with(s, "\n") {
    True -> s
    False -> s <> "\n"
  }
}

/// gleamgen drops `import swil/runtime/api_help` when the module body only references `api_help` via raw strings.
fn ensure_api_help_import(text: String) -> String {
  case
    string.contains(text, "api_help.")
    && !string.contains(text, "import swil/runtime/api_help")
  {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport swil/runtime/api_help\n" <> string.join(rest, "\n")
      }
    }
  }
}

/// gleamgen may omit `dsl` when return types only use `dsl.` inside raw strings.
fn ensure_dsl_import(text: String) -> String {
  case string.contains(text, "dsl.") && !string.contains(text, "dsl") {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport swil/dsl as dsl\n" <> string.join(rest, "\n")
      }
    }
  }
}

/// gleamgen may omit `gleam/option` when bodies use `option.*` only via raw strings.
fn strip_option_import_if_unused(text: String) -> String {
  case string.contains(text, "option.") {
    True -> text
    False -> string.replace(text, "import gleam/option\n", "")
  }
}

fn ensure_option_import(text: String) -> String {
  let needs_option =
    string.contains(text, "option.None")
    || string.contains(text, "option.Some(")
    || string.contains(text, "option.Option(")
  case needs_option && !string.contains(text, "import gleam/option") {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport gleam/option\n" <> string.join(rest, "\n")
      }
    }
  }
}

/// gleamgen drops `import gleam/dynamic/decode` when only raw decoder pipelines reference `decode`.
fn ensure_decode_import(text: String) -> String {
  case
    string.contains(text, "decode.")
    && !string.contains(text, "import gleam/dynamic/decode")
  {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport gleam/dynamic/decode\n" <> string.join(rest, "\n")
      }
    }
  }
}

fn ensure_list_import(text: String) -> String {
  case
    string.contains(text, "list.")
    && !string.contains(text, "import gleam/list")
  {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport gleam/list\n" <> string.join(rest, "\n")
      }
    }
  }
}

fn ensure_string_import(text: String) -> String {
  case
    string.contains(text, "string.")
    && !string.contains(text, "import gleam/string")
  {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport gleam/string\n" <> string.join(rest, "\n")
      }
    }
  }
}

fn ensure_result_import(text: String) -> String {
  case
    string.contains(text, "result.")
    && !string.contains(text, "import gleam/result")
  {
    False -> text
    True -> {
      case string.split(text, "\n") {
        [] -> text
        [first, ..rest] ->
          first <> "\nimport gleam/result\n" <> string.join(rest, "\n")
      }
    }
  }
}

fn ensure_row_relationship_type_qualifiers(text: String) -> String {
  text
  |> string.replace("BelongsTo(", "dsl.BelongsTo(")
  |> string.replace("Mutual(", "dsl.Mutual(")
  |> string.replace("BacklinkWith(", "dsl.BacklinkWith(")
  |> string.replace("option.Option(BelongsTo(", "option.Option(dsl.BelongsTo(")
  |> string.replace("option.Option(Mutual(", "option.Option(dsl.Mutual(")
  |> string.replace("option.Option(BacklinkWith(", "option.Option(dsl.BacklinkWith(")
}

fn format_parse_error(e: schema_definition.ParseError) -> String {
  case e {
    schema_definition.GlanceError(_) -> "glance parse error in predicate"
    schema_definition.UnsupportedSchema(_, _, msg) ->
      "unsupported predicate schema: " <> msg
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

/// Emits `row`, `get`, `query`, `api` (facade), and `cmd` modules under `*_db/`.
pub fn generate_api_db_outputs(
  schema_path: String,
  def: SchemaDefinition,
) -> Result(ApiDbOutputs, String) {
  let assert [first_entity, ..] = def.entities
  let ctx = dec.type_ctx(schema_path, def)
  let exposing = schema_context.api_schema_exposing_all(def)
  let types_only_exposing = schema_context.api_schema_types_only_exposing(def)
  let migration_path = schema_context.migration_import_path(schema_path)
  let db_path = schema_context.db_module_path_from_schema(schema_path)
  let table = string.lowercase(first_entity.type_name)
  let data_fields = api_sql.entity_data_fields(first_entity)
  let data_col_labels = list.map(data_fields, fn(f) { f.label })
  let returning = api_sql.full_row_columns(data_col_labels)
  let entity_snake = string.lowercase(first_entity.type_name)

  let generated_query_specs =
    list.filter(def.queries, fn(q) {
      api_query.query_spec_targets_entity(q, first_entity)
    })

  // Complex recursive filter query specs (target any entity).
  let complex_recursive_specs =
    list.filter(def.queries, fn(q) {
      case q.query {
        Query(filter: Some(ComplexRecursive(..)), ..) -> True
        _ -> False
      }
    })

  let row_t = gtypes.raw(dec.entity_row_tuple_type(ctx, first_entity.type_name))
  let sql_err = gtypes.raw("sqlight.Error")

  let row_chunks =
    list.flat_map(def.entities, fn(e) {
      let id_e = schema_context.find_identity(def, e)
      let assert Ok(variant_e) = list.first(id_e.variants)
      api_chunks.row_module_fn_chunks(
        def,
        string.lowercase(e.type_name),
        e,
        variant_e,
        ctx,
      )
    })

  let row_mod =
    api_imports.with_row_module_imports(
      db_path,
      schema_path,
      def,
      exposing,
      fn() { fold_fn_chunks(row_chunks, gmod.eof()) },
    )

  let get_const_entries =
    list.flat_map(def.entities, fn(e) {
      let table_e = string.lowercase(e.type_name)
      let id_e = schema_context.find_identity(def, e)
      let data_cols_e =
        api_sql.entity_data_fields(e)
        |> list.map(fn(f) { f.label })
      let returning_e = api_sql.full_row_columns(data_cols_e)
      let select_by_id_e =
        api_sql.select_by_identity_sql(table_e, returning_e, ["id"])
      list.append(
        list.map(id_e.variants, fn(variant_e) {
          let id_snake_e = case
            string.starts_with(variant_e.variant_name, "By")
          {
            True ->
              api_naming.pascal_to_snake(string.drop_start(
                variant_e.variant_name,
                2,
              ))
            False -> api_naming.pascal_to_snake(variant_e.variant_name)
          }
          let id_cols_e = list.map(variant_e.fields, fn(f) { f.label })
          let select_by_identity_e =
            api_sql.select_by_identity_sql(table_e, returning_e, id_cols_e)
          #(
            "select_" <> table_e <> "_by_" <> id_snake_e <> "_sql",
            Some(select_by_identity_e),
          )
        }),
        [#("select_" <> table_e <> "_by_id_sql", Some(select_by_id_e))],
      )
    })
  let get_fn_chunks =
    list.flat_map(def.entities, fn(e) {
      let id_e = schema_context.find_identity(def, e)
      let assert Ok(first_variant_e) = list.first(id_e.variants)
      list.map(id_e.variants, fn(variant_e) {
        let id_snake_e = case string.starts_with(variant_e.variant_name, "By") {
          True ->
            api_naming.pascal_to_snake(string.drop_start(
              variant_e.variant_name,
              2,
            ))
          False -> api_naming.pascal_to_snake(variant_e.variant_name)
        }
        let get_params_e =
          list.append(
            [api_params.conn_param()],
            api_params.identity_gparams(variant_e),
          )
        api_chunks.get_module_fn_chunks(
          e,
          variant_e,
          string.lowercase(e.type_name),
          id_snake_e,
          get_params_e,
          variant_e.variant_name == first_variant_e.variant_name,
          row_t,
          sql_err,
          ctx,
        )
      })
      |> list.flatten
    })
  let get_mod =
    api_imports.with_get_module_imports(
      db_path,
      schema_path,
      def,
      types_only_exposing,
      fn() {
        get_const_entries
        |> fold_constants(fold_fn_chunks(get_fn_chunks, gmod.eof()))
      },
    )

  let query_const_entries =
    list.append(
      list.flat_map(def.entities, fn(e) {
        let table_e = string.lowercase(e.type_name)
        let data_cols_e =
          api_sql.entity_data_fields(e)
          |> list.map(fn(f) { f.label })
        let returning_e = api_sql.full_row_columns(data_cols_e)
        [
          #(
            "last_100_" <> table_e <> "_sql",
            Some(api_sql.last_100_sql(table_e, returning_e)),
          ),
          #(
            "page_edited_" <> table_e <> "_sql",
            Some(api_sql.page_edited_sql(table_e, returning_e)),
          ),
        ]
      }),
      list.map(generated_query_specs, fn(spec) {
        #(
          api_query.query_sql_const_name(spec.name),
          custom_query_sql(table, returning, spec.query),
        )
      }),
    )
  let query_fn_chunks =
    list.append(
      list.flat_map(def.entities, fn(e) {
        let entity_snake_e = string.lowercase(e.type_name)
        let row_t_e = gtypes.raw(dec.entity_row_tuple_type(ctx, e.type_name))
        api_chunks.query_module_fn_chunks(
          entity_snake_e,
          "last_100_" <> entity_snake_e <> "_sql",
          "page_edited_" <> entity_snake_e <> "_sql",
          row_t_e,
          sql_err,
          ctx,
          [],
        )
      }),
      api_query.generated_query_fn_chunks(
        entity_snake,
        row_t,
        sql_err,
        ctx,
        generated_query_specs,
      ),
    )
  let query_mod =
    api_imports.with_query_module_imports(
      db_path,
      schema_path,
      def,
      types_only_exposing,
      fn() {
        query_const_entries
        |> fold_constants(fold_fn_chunks(query_fn_chunks, gmod.eof()))
      },
    )

  let facade_chunks =
    facade.facade_fn_chunks(
      def,
      sql_err,
      ctx,
      generated_query_specs,
      complex_recursive_specs,
    )
  let api_mod =
    api_imports.with_facade_module_imports(
      migration_path,
      db_path,
      schema_path,
      def,
      types_only_exposing,
      fn() { fold_fn_chunks(facade_chunks, gmod.eof()) },
    )

  let row_text =
    string.replace(dec.row_types_appendage(def, ctx), "calendar.Date", "Date")
    <> "\n"
    <> render_module(row_mod)
    <> dec.subset_output_appendage(generated_query_specs)
  let row_text = ensure_row_relationship_type_qualifiers(row_text)
  let row_text = ensure_api_help_import(row_text)
  let row_text = ensure_decode_import(row_text)
  let row_text = ensure_option_import(row_text)
  let row_text = ensure_dsl_import(row_text)
  let get_text = ensure_dsl_import(render_module(get_mod))

  // Build raw query text and append complex filter code.
  let raw_query_text =
    render_module(query_mod)
    |> ensure_option_import
    |> ensure_dsl_import

  use complex_filter_parts <- result.try(
    list.fold(complex_recursive_specs, Ok([]), fn(acc, spec) {
      use acc_parts <- result.try(acc)
      case spec.query {
        Query(
          filter: Some(ComplexRecursive(
            filter_param_name: fpn,
            predicate_fn_name: pred_fn_name,
          )),
          ..,
        ) -> {
          case
            list.find(def.predicate_functions, fn(f) { f.name == pred_fn_name })
          {
            Error(_) ->
              Error("predicate function not found in schema: " <> pred_fn_name)
            Ok(pred_fn) -> {
              case predicate_parser.parse(pred_fn) {
                Error(e) ->
                  Error(
                    "failed to parse predicate "
                    <> pred_fn_name
                    <> ": "
                    <> format_parse_error(e),
                  )
                Ok(pred_spec) -> {
                  let root_entity =
                    list.find(def.entities, fn(e) {
                      e.type_name == pred_spec.root_entity_type
                    })
                    |> result.unwrap(first_entity)
                  let data_cols =
                    api_sql.entity_data_fields(root_entity)
                    |> list.map(fn(f) { f.label })
                  let all_cols =
                    list.append(data_cols, [
                      "id",
                      "created_at",
                      "updated_at",
                      "deleted_at",
                    ])
                  let select_cols_sql =
                    list.map(all_cols, fn(c) { "\\\"" <> c <> "\\\"" })
                    |> string.join(", ")
                  let filter_param_match =
                    list.find(spec.parameters, fn(p) {
                      api_query.schema_query_param_name(p) == fpn
                      || p.name == fpn
                    })
                  let filter_param_type =
                    filter_param_match
                    |> result.map(fn(p) { dec.render_type(p.type_, ctx) })
                    |> result.unwrap(
                      ctx.schema_alias <> "." <> pred_spec.leaf_param_type,
                    )
                  let filter_param_binding =
                    filter_param_match
                    |> result.map(fn(p) { api_query.schema_query_param_name(p) })
                    |> result.unwrap("filter")
                  let filter_prefix =
                    string.lowercase(pred_spec.target_entity_type)
                  let gen_ctx =
                    complex_filter_sql.ComplexFilterGenCtx(
                      schema_alias: ctx.schema_alias,
                      filter_param_type: filter_param_type,
                      leaf_scalar_type: ctx.schema_alias
                        <> "."
                        <> pred_spec.leaf_param_type,
                      row_tuple_type: dec.entity_row_tuple_type(
                        ctx,
                        pred_spec.root_entity_type,
                      ),
                      row_decoder_fn: string.lowercase(
                        pred_spec.root_entity_type,
                      )
                        <> "_with_magic_row_decoder",
                      select_cols_sql: select_cols_sql,
                      root_table: string.lowercase(pred_spec.root_entity_type),
                      root_alias: "tb",
                      order_sql: "tb.\\\"updated_at\\\" desc",
                      filter_prefix: filter_prefix,
                      filter_param_binding: filter_param_binding,
                    )
                  let sql_code =
                    complex_filter_sql.emit_complex_filter_query(
                      pred_spec,
                      gen_ctx,
                      spec.name,
                    )
                  let leaf_dec_fn = filter_prefix <> "_expression_decoder"
                  let bool_dec_fn = "filter_expression_decoder"
                  let decoder_code =
                    complex_filter_sql.emit_bool_filter_decoder(
                      bool_dec_fn,
                      leaf_dec_fn,
                      filter_param_type,
                    )
                  let leaf_decoder_code =
                    complex_filter_sql.emit_leaf_scalar_decoder(
                      leaf_dec_fn,
                      ctx.schema_alias <> "." <> pred_spec.leaf_param_type,
                      ctx.schema_alias,
                      pred_spec,
                    )
                  let part =
                    "\n\n"
                    <> sql_code
                    <> "\n\n"
                    <> decoder_code
                    <> "\n\n"
                    <> leaf_decoder_code
                  Ok([part, ..acc_parts])
                }
              }
            }
          }
        }
        _ -> Ok(acc_parts)
      }
    }),
  )

  let raw_query_text =
    raw_query_text <> string.join(list.reverse(complex_filter_parts), "")
  let raw_query_text =
    raw_query_text
    |> ensure_decode_import
    |> ensure_list_import
    |> ensure_string_import

  let api_text =
    render_module(api_mod)
    |> ensure_option_import
    |> ensure_dsl_import
    |> ensure_list_import
  use row_text <- result.try(gleam_fmt.format_generated_source(row_text))
  use get_text <- result.try(gleam_fmt.format_generated_source(get_text))
  use query_text <- result.try(
    gleam_fmt.format_generated_source(raw_query_text)
    |> result.map(strip_option_import_if_unused),
  )
  use api_text <- result.try(gleam_fmt.format_generated_source(api_text))
  let junction_append = pragma_migration.generate_junction_upserts_gleam_appendage(
    def,
  )
  let cmd_stitched =
    api_cmd.generate_cmd_module(schema_path, def) <> junction_append
  let cmd_stitched =
    cmd_stitched
    |> ensure_decode_import
    |> ensure_result_import
  use cmd_text <- result.try(gleam_fmt.format_generated_source(cmd_stitched))
  Ok(ApiDbOutputs(
    row: row_text,
    get: get_text,
    query: query_text,
    api: api_text,
    cmd: cmd_text,
  ))
}

/// Backwards-compatible: returns only the `api.gleam` facade source.
pub fn generate_api(
  schema_path: String,
  schema: SchemaDefinition,
) -> Result(String, String) {
  use outs <- result.try(generate_api_db_outputs(schema_path, schema))
  Ok(outs.api)
}
