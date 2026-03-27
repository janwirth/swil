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
  type EntityDefinition, type IdentityVariantDefinition, type QueryParameter,
  type QuerySpecDefinition, type SchemaDefinition, LtMissingFieldAsc,
}

import generators/api/api_decoders as dec
import generators/api/schema_context

fn param_names_csv(params: List(gparam.Parameter(gtypes.Dynamic))) -> String {
  list.map(params, gparam.name)
  |> string.join(", ")
}

fn forward_fn(
  submodule: String,
  fn_name: String,
  params: List(gparam.Parameter(gtypes.Dynamic)),
  ret: gtypes.GeneratedType(r),
  sql_err: gtypes.GeneratedType(e),
) {
  let names = param_names_csv(params)
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
  let names = param_names_csv(params)
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

fn scalar_forward_chunks(def: SchemaDefinition, entity: EntityDefinition) {
  schema_context.entity_used_enum_scalars(def, entity)
  |> list.flat_map(fn(s) {
    let base = dec.scalar_type_snake_case(s.type_name)
    let from_n = base <> "_from_db_string"
    let to_n = base <> "_to_db_string"
    let opt_t = gtypes.raw("Option(" <> s.type_name <> ")")
    [
      #(
        gleamgen_emit.pub_def(from_n),
        gfun.new_raw(
          [gparam.new("s", gtypes.string) |> gparam.to_dynamic],
          opt_t,
          fn(_) { gexpr.raw("row." <> from_n <> "(s)") },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gleamgen_emit.pub_def(to_n),
        gfun.new_raw(
          [gparam.new("o", opt_t) |> gparam.to_dynamic],
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
  let assert LtMissingFieldAsc(
    column: _,
    threshold_param: _,
    shape_param: shape_param,
  ) = spec.codegen
  let fn_params =
    list.append(
      [api_params.conn_param()],
      list.map(
        list.filter(spec.parameters, fn(p) {
          p.name != shape_param && !param_is_magic_fields(p)
        }),
        fn(p) {
          gparam.new(
            api_query.schema_query_param_name(p),
            gtypes.raw(dec.render_type(p.type_, ctx)),
          )
          |> gparam.to_dynamic
        },
      ),
    )
  forward_fn("query", spec.name, fn_params, gtypes.list(row_t), sql_err)
}

fn param_is_magic_fields(p: QueryParameter) -> Bool {
  case p.type_ {
    glance.NamedType(_, "MagicFields", _, []) -> True
    _ -> False
  }
}

pub fn facade_fn_chunks(
  def: SchemaDefinition,
  entity: EntityDefinition,
  _variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  upsert_params: List(gparam.Parameter(gtypes.Dynamic)),
  get_params: List(gparam.Parameter(gtypes.Dynamic)),
  row_t,
  sql_err,
  ctx: dec.TypeCtx,
  generated_query_specs: List(QuerySpecDefinition),
) {
  let upsert_name = "upsert_" <> entity_snake <> "_by_" <> id_snake
  let get_name = "get_" <> entity_snake <> "_by_" <> id_snake
  let update_name = "update_" <> entity_snake <> "_by_" <> id_snake
  let delete_name = "delete_" <> entity_snake <> "_by_" <> id_snake
  let last_name = "last_100_edited_" <> entity_snake
  let row_opt =
    gtypes.raw("Option(" <> dec.entity_row_tuple_type(entity.type_name) <> ")")
  list.flatten([
    [forward_fn("upsert", upsert_name, upsert_params, row_t, sql_err)],
    [forward_fn("upsert", get_name, get_params, row_opt, sql_err)],
    [forward_fn("upsert", update_name, upsert_params, row_t, sql_err)],
    [forward_fn_nil_result("delete", delete_name, get_params, sql_err)],
    [
      forward_fn(
        "query",
        last_name,
        [api_params.conn_param()],
        gtypes.list(row_t),
        sql_err,
      ),
    ],
    list.map(generated_query_specs, fn(s) {
      query_spec_forward_chunk(s, row_t, sql_err, ctx)
    }),
    scalar_forward_chunks(def, entity),
    [migrate_chunk(sql_err)],
  ])
}
