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
import gleamgen/types/custom as gcustom
import gleamgen/types/variant as gvariant

pub fn generate(ctx: SchemaContext) -> String {
  let upsert = ctx.for_upsert_type_name
  let uv = ctx.for_upsert_variant_name
  let singular = ctx.singular
  let with_suffix = string.join(ctx.identity_labels, "_")

  let option_mod =
    gim.new_with_exposing(["gleam", "option"], "type Option")

  let arg_pairs =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      let typ_out = case list.contains(ctx.identity_labels, label) {
        True -> sql_types.identity_upsert_param_type(typ)
        False -> sql_types.rendered_type(typ)
      }
      #(option.Some(label), gtypes.raw(typ_out) |> gtypes.to_dynamic)
    })
  let upsert_variant =
    gvariant.with_arguments_dynamic(gvariant.new(uv), arg_pairs)

  let custom_builder =
    gcustom.new(Nil)
    |> gcustom.with_dynamic_variants(fn(_) { [upsert_variant] })

  let helper_params =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      let typ_out = case list.contains(ctx.identity_labels, label) {
        True -> sql_types.identity_upsert_param_type(typ)
        False -> sql_types.rendered_type(typ)
      }
      gparam.new(label, gtypes.raw(typ_out)) |> gparam.to_dynamic
    })

  let helper_fn =
    gfun.new_raw(
      parameters: helper_params,
      returns: gtypes.raw(upsert),
      handler: fn(_args) {
        gex.raw(uv <> "(" <> join_field_labels(ctx.fields) <> ")")
      },
    )

  gleamgen_emit.render_module(
    gmod.with_import(option_mod, fn(_) {
      gmod.with_custom_type_dynamic(
        gleamgen_emit.pub_def(upsert),
        custom_builder,
        fn(_ty, _ctors) {
          gmod.with_function(
            gleamgen_emit.pub_def(singular <> "_with_" <> with_suffix),
            helper_fn,
            fn(_) { gmod.eof() },
          )
        },
      )
    }),
  )
}

fn join_field_labels(fields: List(#(String, a))) -> String {
  case fields {
    [] -> ""
    [#(l, _), ..rest] ->
      l
      <> ":"
      <> case rest {
        [] -> ""
        _ -> ", " <> join_field_labels(rest)
      }
  }
}
