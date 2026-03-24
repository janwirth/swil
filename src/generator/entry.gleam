import gleam/list
import gleam/option
import gleam/string

import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext}
import generator/sql_types

import gleamgen/expression as gex
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/parameter as gparam
import gleamgen/types as gtypes

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let schema_mod = ctx.schema_module
  let t = ctx.type_name
  let singular = ctx.singular
  let table_fn = ctx.table
  let row = ctx.row_name
  let db = ctx.db_type_name
  let filterable = ctx.filterable_name
  let upsert = ctx.for_upsert_type_name
  let field_enum = ctx.field_enum_name
  let num_ref = "Num" <> t <> "Field"
  let str_ref = "String" <> t <> "Field"

  let header =
    "// Main entry for the "
    <> table_fn
    <> " schema: import this module for `"
    <> t
    <> "`, row/db types,\n"
    <> "// `"
    <> table_fn
    <> "` / `migrate_idempotent`, and `"
    <> singular
    <> "` (constructor helper).\n\n"

  let option_mod =
    gim.new_with_exposing(["gleam", "option"], "type Option")
  let sqlight_mod = gim.new(["sqlight"])
  let crud_mod = gim.new([layer, "crud"])
  let migrate_mod = gim.new([layer, "migrate"])
  let resource_mod = gim.new([layer, "resource"])
  let structure_mod = gim.new([layer, "structure"])
  let schema_import =
    gim.new_with_exposing(
      [schema_mod],
      "type " <> t <> ", " <> ctx.variant_name,
    )

  let conn_t =
    gtypes.custom_type(option.Some("sqlight"), "Connection", [])
  let migrate_ret =
    gtypes.result(
      gtypes.nil,
      gtypes.custom_type(option.Some("sqlight"), "Error", []),
    )
  let db_t = gtypes.raw(db)

  let ctor_params =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      gparam.new(label, gtypes.raw(sql_types.rendered_type(typ)))
      |> gparam.to_dynamic
    })

  let ctor_fn =
    gfun.new_raw(
      parameters: ctor_params,
      returns: gtypes.raw(t),
      handler: fn(_args) {
        gex.raw(
          ctx.variant_name <> "(" <> join_label_shorthands(ctx.fields) <> ")",
        )
      },
    )

  let upsert_identity_params =
    list.map(ctx.identity_labels, fn(label) {
      let assert Ok(#(_, typ)) =
        list.find(ctx.fields, fn(pair) { pair.0 == label })
      gparam.new(label, gtypes.raw(sql_types.identity_upsert_param_type(typ)))
      |> gparam.to_dynamic
    })
  let upsert_rest_params =
    ctx.fields
    |> list.filter(fn(pair) { !list.contains(ctx.identity_labels, pair.0) })
    |> list.map(fn(pair) {
      let #(label, typ) = pair
      gparam.new(label, gtypes.raw(sql_types.rendered_type(typ)))
      |> gparam.to_dynamic
    })
  let upsert_helper_params =
    list.append(upsert_identity_params, upsert_rest_params)

  let upsert_helper_fn =
    gfun.new_raw(
      parameters: upsert_helper_params,
      returns: gtypes.raw(upsert),
      handler: fn(_args) {
        gex.raw(
          "resource."
          <> singular
          <> "_with_"
          <> identity_suffix(ctx)
          <> "("
          <> resource_with_helper_args(ctx)
          <> ")",
        )
      },
    )

  let table_fn_inner =
    gfun.new1(
      gparam.new("conn", conn_t),
      db_t,
      fn(_conn) {
        gex.raw("crud." <> table_fn <> "(conn)")
      },
    )

  let migrate_fn =
    gfun.new1(
      gparam.new("conn", conn_t),
      migrate_ret,
      fn(_conn) {
        gex.raw("migrate.migrate_idempotent(conn)")
      },
    )

  header
  <> gleamgen_emit.render_module(
    gmod.with_import(option_mod, fn(_) {
      gmod.with_import(sqlight_mod, fn(_) {
        gmod.with_import(crud_mod, fn(_) {
          gmod.with_import(migrate_mod, fn(_) {
            gmod.with_import(resource_mod, fn(_) {
              gmod.with_import(structure_mod, fn(_) {
                gmod.with_import(schema_import, fn(_) {
                  gmod.with_type_alias(
                    gleamgen_emit.pub_def(upsert),
                    gtypes.raw("resource." <> upsert),
                    fn(_) {
                      gmod.with_type_alias(
                        gleamgen_emit.pub_def(row),
                        gtypes.raw("structure." <> row),
                        fn(_) {
                          gmod.with_type_alias(
                            gleamgen_emit.pub_def(db),
                            gtypes.raw("structure." <> db),
                            fn(_) {
                              gmod.with_type_alias(
                                gleamgen_emit.pub_def(filterable),
                                gtypes.raw("structure." <> filterable),
                                fn(_) {
                                  gmod.with_type_alias(
                                    gleamgen_emit.pub_def(
                                      "StringRefOrValue",
                                    ),
                                    gtypes.raw(
                                      "structure.StringRefOrValue",
                                    ),
                                    fn(_) {
                                      gmod.with_type_alias(
                                        gleamgen_emit.pub_def(
                                          "NumRefOrValue",
                                        ),
                                        gtypes.raw(
                                          "structure.NumRefOrValue",
                                        ),
                                        fn(_) {
                                          gmod.with_type_alias(
                                            gleamgen_emit.pub_def(num_ref),
                                            gtypes.raw(
                                              "structure." <> num_ref,
                                            ),
                                            fn(_) {
                                              gmod.with_type_alias(
                                                gleamgen_emit.pub_def(
                                                  str_ref,
                                                ),
                                                gtypes.raw(
                                                  "structure." <> str_ref,
                                                ),
                                                fn(_) {
                                                  gmod.with_type_alias(
                                                    gleamgen_emit.pub_def(
                                                      field_enum,
                                                    ),
                                                    gtypes.raw(
                                                      "structure."
                                                      <> field_enum,
                                                    ),
                                                    fn(_) {
                                                      gmod.with_function(
                                                        gleamgen_emit.pub_def(
                                                          singular,
                                                        ),
                                                        ctor_fn,
                                                        fn(_) {
                                                          gmod.with_function(
                                                            gleamgen_emit.pub_def(
                                                              singular
                                                              <> "_with_"
                                                              <> identity_suffix(
                                                                ctx,
                                                              ),
                                                            ),
                                                            upsert_helper_fn,
                                                            fn(_) {
                                                              gmod.with_function(
                                                                gleamgen_emit.pub_def(
                                                                  table_fn,
                                                                ),
                                                                table_fn_inner,
                                                                fn(_) {
                                                                  gmod.with_function(
                                                                    gleamgen_emit.pub_def(
                                                                      "migrate_idempotent",
                                                                    ),
                                                                    migrate_fn,
                                                                    fn(_) {
                                                                      gmod.eof()
                                                                    },
                                                                  )
                                                                },
                                                              )
                                                            },
                                                          )
                                                        },
                                                      )
                                                    },
                                                  )
                                                },
                                              )
                                            },
                                          )
                                        },
                                      )
                                    },
                                  )
                                },
                              )
                            },
                          )
                        },
                      )
                    },
                  )
                })
              })
            })
          })
        })
      })
    }),
  )
}

fn join_label_shorthands(fields: List(#(String, a))) -> String {
  case fields {
    [] -> ""
    [#(l, _), ..rest] ->
      l
      <> ":"
      <> case rest {
        [] -> ""
        _ -> ", " <> join_label_shorthands(rest)
      }
  }
}

fn identity_suffix(ctx: SchemaContext) -> String {
  string.join(ctx.identity_labels, "_")
}

fn resource_with_helper_args(ctx: SchemaContext) -> String {
  ctx.fields
  |> list.map(fn(pair) { pair.0 })
  |> string.join(", ")
}
