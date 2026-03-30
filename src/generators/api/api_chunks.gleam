import generators/api/api_crud_bodies as crud_bodies
import generators/api/api_decoders as dec
import generators/api/api_params
import generators/api/api_query
import generators/api/api_update_delete as ud
import generators/api/scalar_codecs
import generators/gleamgen_emit
import gleam/list
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type IdentityVariantDefinition,
  type QuerySpecDefinition, type SchemaDefinition,
}

pub fn not_found_private_chunk(entity_snake: String, not_found_fn: String) {
  #(
    gdef.new(not_found_fn) |> gdef.with_publicity(False),
    gfun.new1(
      param1: gparam.new("op", gtypes.string),
      returns: gtypes.raw("sqlight.Error"),
      handler: fn(op) {
        gexpr.call3(
          gexpr.raw("sqlight.SqlightError"),
          gexpr.raw("sqlight.GenericError"),
          gexpr.concat_string(
            gexpr.concat_string(
              gexpr.string(entity_snake),
              gexpr.string(" not found: "),
            ),
            op,
          ),
          gexpr.int(-1),
        )
      },
    )
      |> gfun.to_dynamic,
  )
}

pub fn row_module_fn_chunks(
  def: SchemaDefinition,
  entity_snake: String,
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  ctx: dec.TypeCtx,
) {
  let decode_pair =
    dec.row_decode_helpers_fn_chunks(entity_snake, def, entity, variant, ctx)
  let decode_ordered = case decode_pair {
    [dec1, dec2] -> [dec2, dec1]
    _ -> decode_pair
  }
  list.flatten([
    decode_ordered,
    scalar_codecs.scalar_db_fn_chunks(def, entity, ctx),
  ])
}

pub fn upsert_module_fn_chunks(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  upsert_params: List(gparam.Parameter(gtypes.Dynamic)),
  row_t,
  sql_err,
  scalar_names: List(String),
) {
  let not_found_fn = "not_found_" <> entity_snake <> "_" <> id_snake <> "_error"
  [
    not_found_private_chunk(entity_snake, not_found_fn),
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
        gexpr.raw(ud.upsert_fn_body(
          entity,
          variant,
          entity_snake,
          id_snake,
          "upsert",
          scalar_names,
          "row",
          "upsert_" <> entity_snake <> "_by_" <> id_snake <> "_sql",
          not_found_fn,
        ))
      })
        |> gfun.to_dynamic,
    ),
    ud.update_fn_chunk(
      entity,
      variant,
      entity_snake,
      id_snake,
      upsert_params,
      row_t,
      sql_err,
      scalar_names,
      not_found_fn,
    ),
  ]
}

pub fn update_by_id_fn_chunks(
  entity: EntityDefinition,
  entity_snake: String,
  params: List(gparam.Parameter(gtypes.Dynamic)),
  row_t,
  sql_err,
  scalar_names: List(String),
) {
  let not_found_fn = "not_found_" <> entity_snake <> "_id_error"
  [
    not_found_private_chunk(entity_snake, not_found_fn),
    ud.update_by_id_fn_chunk(
      entity,
      entity_snake,
      params,
      row_t,
      sql_err,
      scalar_names,
      not_found_fn,
    ),
  ]
}

pub fn get_module_fn_chunks(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  get_params: List(gparam.Parameter(gtypes.Dynamic)),
  include_by_id: Bool,
  _row_t,
  sql_err,
  ctx: dec.TypeCtx,
) {
  list.append(
    [
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
            gtypes.raw(dec.option_entity_row_tuple(ctx, entity.type_name)),
            sql_err,
          ),
          fn(_) {
            gexpr.raw(crud_bodies.get_fn_body(
              variant,
              entity_snake,
              id_snake,
              "row",
              "row",
            ))
          },
        )
          |> gfun.to_dynamic,
      ),
    ],
    case include_by_id {
      True -> [
        #(
          gleamgen_emit.pub_def("get_" <> entity_snake <> "_by_id")
            |> gdef.with_text_before(
              "/// Get a " <> entity_snake <> " by row id.\n",
            ),
          gfun.new_raw(
            [
              api_params.conn_param(),
              api_params.consumer_param("id", gtypes.int),
            ],
            gtypes.result(
              gtypes.raw(dec.option_entity_row_tuple(ctx, entity.type_name)),
              sql_err,
            ),
            fn(_) {
              gexpr.raw(crud_bodies.get_by_id_fn_body(entity_snake, "row"))
            },
          )
            |> gfun.to_dynamic,
        ),
      ]
      False -> []
    },
  )
}

pub fn query_module_fn_chunks(
  entity_snake: String,
  last_100_sql_const_name: String,
  row_t,
  sql_err,
  ctx: dec.TypeCtx,
  specs: List(QuerySpecDefinition),
) {
  list.append(
    [
      #(
        gleamgen_emit.pub_def("last_100_edited_" <> entity_snake)
          |> gdef.with_text_before(
            "/// List up to 100 recently edited " <> entity_snake <> " rows.\n",
          ),
        gfun.new_raw(
          [api_params.conn_param()],
          gtypes.result(gtypes.list(row_t), sql_err),
          fn(_) {
            gexpr.raw(crud_bodies.last_fn_body(
              entity_snake,
              last_100_sql_const_name,
              "row",
            ))
          },
        )
          |> gfun.to_dynamic,
      ),
    ],
    api_query.generated_query_fn_chunks(
      entity_snake,
      row_t,
      sql_err,
      ctx,
      specs,
    ),
  )
}
