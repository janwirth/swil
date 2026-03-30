import generators/api/api_naming
import generators/api/api_params
import generators/api/api_query
import generators/gleamgen_emit
import glance
import gleam/list
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type QuerySpecDefinition, type SchemaDefinition,
  QueryParameter,
}

import generators/api/api_decoders as dec
import generators/api/schema_context

fn param_call_args_csv(params: List(gparam.Parameter(gtypes.Dynamic))) -> String {
  list.map(params, fn(p) {
    case gparam.has_label(p) {
      True -> gparam.name(p) <> ": " <> gparam.name(p)
      False -> gparam.name(p)
    }
  })
  |> string.join(", ")
}

fn forward_fn(
  submodule: String,
  fn_name: String,
  params: List(gparam.Parameter(gtypes.Dynamic)),
  ret: gtypes.GeneratedType(r),
  sql_err: gtypes.GeneratedType(e),
) {
  let names = param_call_args_csv(params)
  #(
    gleamgen_emit.pub_def(fn_name),
    gfun.new_raw(params, gtypes.result(ret, sql_err), fn(_) {
      gexpr.raw(submodule <> "." <> fn_name <> "(" <> names <> ")")
    })
      |> gfun.to_dynamic,
  )
}

fn forward_fn_nil_result(
  submodule: String,
  fn_name: String,
  params: List(gparam.Parameter(gtypes.Dynamic)),
  sql_err: gtypes.GeneratedType(e),
) {
  let names = param_call_args_csv(params)
  #(
    gleamgen_emit.pub_def(fn_name),
    gfun.new_raw(params, gtypes.result(gtypes.nil, sql_err), fn(_) {
      gexpr.raw(submodule <> "." <> fn_name <> "(" <> names <> ")")
    })
      |> gfun.to_dynamic,
  )
}

fn migrate_chunk(sql_err: gtypes.GeneratedType(e)) {
  #(
    gleamgen_emit.pub_def("migrate"),
    gfun.new_raw(
      [api_params.conn_param()],
      gtypes.result(gtypes.nil, sql_err),
      fn(_) { gexpr.raw("migration.migration(conn)") },
    )
      |> gfun.to_dynamic,
  )
}

fn scalar_forward_chunks(
  def: SchemaDefinition,
  entity: EntityDefinition,
  ctx: dec.TypeCtx,
) {
  schema_context.entity_used_enum_scalars(def, entity)
  |> list.flat_map(fn(s) {
    let base = dec.scalar_type_snake_case(s.type_name)
    let from_n = base <> "_from_db_string"
    let to_n = base <> "_to_db_string"
    let opt_t =
      gtypes.raw(
        "option.Option(" <> ctx.schema_alias <> "." <> s.type_name <> ")",
      )
    [
      #(
        gleamgen_emit.pub_def(from_n),
        gfun.new_raw(
          [api_params.consumer_param("s", gtypes.string)],
          opt_t,
          fn(_) { gexpr.raw("row." <> from_n <> "(s)") },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gleamgen_emit.pub_def(to_n),
        gfun.new_raw(
          [api_params.consumer_param("o", opt_t)],
          gtypes.string,
          fn(_) { gexpr.raw("row." <> to_n <> "(o)") },
        )
          |> gfun.to_dynamic,
      ),
    ]
  })
}

fn query_spec_forward_chunk(
  spec: QuerySpecDefinition,
  row_t,
  sql_err: gtypes.GeneratedType(e),
  ctx: dec.TypeCtx,
) {
  let fn_params =
    list.append(
      [api_params.conn_param()],
      list.map(
        case spec.parameters {
          [_, _, simple] -> [simple]
          _ -> []
        },
        fn(p) {
          let n = api_query.schema_query_param_name(p)
          api_params.consumer_param(n, gtypes.raw(dec.render_type(p.type_, ctx)))
        },
      ),
    )
  forward_fn("query", spec.name, fn_params, gtypes.list(row_t), sql_err)
}

fn entity_name_from_spec_params(
  spec: QuerySpecDefinition,
  fallback: String,
) -> String {
  case spec.parameters {
    [QueryParameter(_, _, glance.NamedType(_, name, _, [])), ..] -> name
    _ -> fallback
  }
}

fn complex_query_forward_chunk(
  spec: QuerySpecDefinition,
  sql_err: gtypes.GeneratedType(e),
  ctx: dec.TypeCtx,
  fallback_entity: String,
) {
  let entity_name = entity_name_from_spec_params(spec, fallback_entity)
  let row_t = gtypes.raw(dec.entity_row_tuple_type(ctx, entity_name))
  let fn_params =
    list.append(
      [api_params.conn_param()],
      list.map(
        case spec.parameters {
          [_, _, simple] -> [simple]
          _ -> []
        },
        fn(p) {
          let n = api_query.schema_query_param_name(p)
          api_params.consumer_param(n, gtypes.raw(dec.render_type(p.type_, ctx)))
        },
      ),
    )
  forward_fn("query", spec.name, fn_params, gtypes.list(row_t), sql_err)
}

pub fn facade_fn_chunks(
  def: SchemaDefinition,
  sql_err,
  ctx: dec.TypeCtx,
  generated_query_specs: List(QuerySpecDefinition),
  complex_query_specs: List(QuerySpecDefinition),
) {
  let assert [first_entity, ..] = def.entities
  let first_row_t =
    gtypes.raw(dec.entity_row_tuple_type(ctx, first_entity.type_name))
  let entity_operation_forwards =
    list.flat_map(def.entities, fn(e) {
      let e_snake = string.lowercase(e.type_name)
      let id = schema_context.find_identity(def, e)
      let variant_forwards =
        list.map(id.variants, fn(variant) {
          let id_snake = case string.starts_with(variant.variant_name, "By") {
            True ->
              api_naming.pascal_to_snake(string.drop_start(
                variant.variant_name,
                2,
              ))
            False -> api_naming.pascal_to_snake(variant.variant_name)
          }
          let upsert_name = "upsert_" <> e_snake <> "_by_" <> id_snake
          let upsert_many_name = "upsert_many_" <> e_snake <> "_by_" <> id_snake
          let get_name = "get_" <> e_snake <> "_by_" <> id_snake
          let update_name = "update_" <> e_snake <> "_by_" <> id_snake
          let delete_name = "delete_" <> e_snake <> "_by_" <> id_snake
          let upsert_params =
            list.append(
              [api_params.conn_param()],
              api_params.upsert_gparams(e, variant, ctx),
            )
          let upsert_many_params =
            api_params.upsert_many_gparams(e, variant, ctx, e.type_name)
          let get_params =
            list.append(
              [api_params.conn_param()],
              api_params.identity_gparams(variant),
            )
          let row_t = gtypes.raw(dec.entity_row_tuple_type(ctx, e.type_name))
          let row_opt = gtypes.raw(dec.option_entity_row_tuple(ctx, e.type_name))
          [
            forward_fn("upsert", upsert_name, upsert_params, row_t, sql_err),
            forward_fn(
              "upsert",
              upsert_many_name,
              upsert_many_params,
              gtypes.list(row_t),
              sql_err,
            ),
            forward_fn("get", get_name, get_params, row_opt, sql_err),
            forward_fn("upsert", update_name, upsert_params, row_t, sql_err),
            forward_fn_nil_result("delete", delete_name, get_params, sql_err),
          ]
        })
        |> list.flatten
      let row_t = gtypes.raw(dec.entity_row_tuple_type(ctx, e.type_name))
      let update_by_id_params =
        list.append(
          [api_params.conn_param()],
          api_params.update_by_id_gparams(e, ctx),
        )
      let update_by_id_forward = [
        forward_fn(
          "upsert",
          "update_" <> e_snake <> "_by_id",
          update_by_id_params,
          row_t,
          sql_err,
        ),
      ]
      list.append(variant_forwards, update_by_id_forward)
    })
  list.flatten([
    entity_operation_forwards,
    list.map(def.entities, fn(e) {
      let e_snake = string.lowercase(e.type_name)
      forward_fn(
        "get",
        "get_" <> e_snake <> "_by_id",
        [
          api_params.conn_param(),
          api_params.consumer_param("id", gtypes.int),
        ],
        gtypes.raw(dec.option_entity_row_tuple(ctx, e.type_name)),
        sql_err,
      )
    }),
    list.map(def.entities, fn(e) {
      let e_snake = string.lowercase(e.type_name)
      forward_fn(
        "query",
        "last_100_edited_" <> e_snake,
        [api_params.conn_param()],
        gtypes.list(gtypes.raw(dec.entity_row_tuple_type(ctx, e.type_name))),
        sql_err,
      )
    }),
    list.map(generated_query_specs, fn(s) {
      query_spec_forward_chunk(s, first_row_t, sql_err, ctx)
    }),
    list.map(complex_query_specs, fn(s) {
      complex_query_forward_chunk(s, sql_err, ctx, first_entity.type_name)
    }),
    list.flat_map(def.entities, fn(e) { scalar_forward_chunks(def, e, ctx) }),
    [migrate_chunk(sql_err)],
  ])
}
