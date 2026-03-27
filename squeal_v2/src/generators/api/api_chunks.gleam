import generators/api/api_crud_bodies as crud_bodies
import generators/api/api_decoders as dec
import generators/api/api_params
import generators/api/api_query
import generators/api/api_update_delete as ud
import generators/api/schema_context
import generators/gleamgen_emit
import gleam/list
import gleamgen/expression as gexpr
import gleamgen/expression/case_ as gcase
import gleamgen/function as gfun
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/render/config as grender_cfg
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type IdentityVariantDefinition,
  type QuerySpecDefinition, type SchemaDefinition,
}

fn without_combined_case_branches(e: gexpr.Expression(t)) -> gexpr.Expression(t) {
  gexpr.with_render_config(
    e,
    grender_cfg.Config(
      ..grender_cfg.default_config,
      combine_equivalent_branches: False,
    ),
  )
}

fn scalar_enum_from_db_expr(
  s: gexpr.Expression(String),
  variants: List(String),
) -> gexpr.Expression(a) {
  let c = gcase.new(s)
  let c =
    gcase.with_pattern(c, gpat.string_literal(""), fn(_) { gexpr.raw("None") })
  let c =
    list.fold(variants, c, fn(acc, v) {
      gcase.with_pattern(acc, gpat.string_literal(v), fn(_) {
        gexpr.call1(gexpr.raw("Some"), gexpr.raw(v))
      })
    })
  let c = gcase.with_pattern(c, gpat.discard(), fn(_) { gexpr.raw("None") })
  gcase.build_expression(c) |> without_combined_case_branches
}

fn scalar_enum_to_db_expr(
  o: gexpr.Expression(gtypes.Dynamic),
  variants: List(String),
) -> gexpr.Expression(String) {
  let c = gcase.new(o)
  let c = gcase.with_pattern(c, gpat.option_none(), fn(_) { gexpr.string("") })
  let c =
    list.fold(variants, c, fn(acc, v) {
      gcase.with_pattern(
        acc,
        gpat.option_some(gpat.foreign_variant(v, [])),
        fn(_args) { gexpr.string(v) },
      )
    })
  gcase.build_expression(c) |> without_combined_case_branches
}

pub fn scalar_enum_db_fn_chunks(def: SchemaDefinition, entity: EntityDefinition) {
  schema_context.entity_used_enum_scalars(def, entity)
  |> list.flat_map(fn(scalar) {
    let base = dec.scalar_type_snake_case(scalar.type_name)
    let from_fn = base <> "_from_db_string"
    let to_fn = base <> "_to_db_string"
    let opt_scalar = gtypes.raw("Option(" <> scalar.type_name <> ")")
    [
      #(
        gleamgen_emit.pub_def(from_fn),
        gfun.new1(
          param1: gparam.new("s", gtypes.string),
          returns: opt_scalar,
          handler: fn(s) { scalar_enum_from_db_expr(s, scalar.variant_names) },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gleamgen_emit.pub_def(to_fn),
        gfun.new1(
          param1: gparam.new("o", opt_scalar),
          returns: gtypes.string,
          handler: fn(o) {
            scalar_enum_to_db_expr(gexpr.to_dynamic(o), scalar.variant_names)
          },
        )
          |> gfun.to_dynamic,
      ),
    ]
  })
}

pub fn not_found_private_chunk(entity_snake: String) {
  #(
    gdef.new("not_found_error") |> gdef.with_publicity(False),
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
    scalar_enum_db_fn_chunks(def, entity),
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
  enum_scalar_names: List(String),
) {
  [
    not_found_private_chunk(entity_snake),
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
          enum_scalar_names,
          "row",
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
      enum_scalar_names,
    ),
  ]
}

pub fn get_module_fn_chunks(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  get_params: List(gparam.Parameter(gtypes.Dynamic)),
  _row_t,
  sql_err,
) {
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
          gtypes.raw(
            "Option(" <> dec.entity_row_tuple_type(entity.type_name) <> ")",
          ),
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
    #(
      gleamgen_emit.pub_def("get_" <> entity_snake <> "_by_id")
        |> gdef.with_text_before(
          "/// Get a "
          <> entity_snake
          <> " by row id.\n",
        ),
      gfun.new_raw(
        [
          api_params.conn_param(),
          gparam.new("id", gtypes.int) |> gparam.to_dynamic,
        ],
        gtypes.result(
          gtypes.raw("Option(" <> dec.entity_row_tuple_type(entity.type_name) <> ")"),
          sql_err,
        ),
        fn(_) {
          gexpr.raw(
            "use rows <- result.try(sqlight.query(\n    select_"
            <> entity_snake
            <> "_by_id_sql,\n    on: conn,\n    with: [sqlight.int(id)],\n    expecting: row."
            <> entity_snake
            <> "_with_magic_row_decoder(),\n  ))\n  case rows {\n    [] -> Ok(None)\n    [r, ..] -> Ok(Some(r))\n  }",
          )
        },
      )
        |> gfun.to_dynamic,
    ),
  ]
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
            gexpr.raw(
              crud_bodies.last_fn_body(entity_snake, last_100_sql_const_name, "row"),
            )
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
