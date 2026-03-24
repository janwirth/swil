import gleam/list
import gleam/option.{Some}
import gleam/string

import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext, pascal_case_field_label}

import gleamgen/expression as gex
import gleamgen/expression/case_ as gcase
import gleamgen/expression/constructor as gcon
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/types as gtypes
import gleamgen/types/variant as gvariant

pub fn generate(ctx: SchemaContext) -> String {
  let structure_mod = gim.new([ctx.layer, "structure"])
  let structure_ref = gim.get_reference(structure_mod)
  let field_type =
    gtypes.custom_type(Some(structure_ref), ctx.field_enum_name, [])
  let fn_name = string.concat([ctx.singular, "_field_sql"])
  let func =
    gfun.new1(
      gparam.new("field", field_type),
      gtypes.string,
      fn(field_expr) {
        build_field_sql_case(ctx, structure_ref, field_expr)
        |> gcase.build_expression()
      },
    )
  let body =
    gleamgen_emit.render_module(
      gmod.with_function(gleamgen_emit.pub_def(fn_name), func, fn(_) {
        gmod.eof()
      }),
    )
  // One explicit import line: module render can emit the same path again when
  // parameter types and case patterns both record `structure` in `used_imports`.
  "import " <> ctx.layer <> "/structure\n" <> body
}

fn build_field_sql_case(
  ctx: SchemaContext,
  structure_ref: String,
  field_expr: gex.Expression(a),
) -> gcase.CaseExpression(a, String) {
  let schema_arms =
    list.map(ctx.fields, fn(pair) {
      let #(label, _) = pair
      let variant =
        string.concat([
          structure_ref,
          ".",
          pascal_case_field_label(label),
          "Field",
        ])
      let m =
        gpat.from_constructor0(
          gcon.new(gvariant.new(variant) |> gvariant.to_dynamic),
        )
      #(m, fn(_) { gex.string(label) })
    })
  let system_arms = [
    #(
      gpat.from_constructor0(
        gcon.new(
          gvariant.new(string.concat([structure_ref, ".IdField"]))
          |> gvariant.to_dynamic,
        ),
      ),
      fn(_) { gex.string("id") },
    ),
    #(
      gpat.from_constructor0(
        gcon.new(
          gvariant.new(string.concat([structure_ref, ".CreatedAtField"]))
          |> gvariant.to_dynamic,
        ),
      ),
      fn(_) { gex.string("created_at") },
    ),
    #(
      gpat.from_constructor0(
        gcon.new(
          gvariant.new(string.concat([structure_ref, ".UpdatedAtField"]))
          |> gvariant.to_dynamic,
        ),
      ),
      fn(_) { gex.string("updated_at") },
    ),
    #(
      gpat.from_constructor0(
        gcon.new(
          gvariant.new(string.concat([structure_ref, ".DeletedAtField"]))
          |> gvariant.to_dynamic,
        ),
      ),
      fn(_) { gex.string("deleted_at") },
    ),
  ]
  let arms = list.append(schema_arms, system_arms)
  list.fold(arms, gcase.new(field_expr), fn(c, arm) {
    let #(m, h) = arm
    gcase.with_pattern(c, m, h)
  })
}
