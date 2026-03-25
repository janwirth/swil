//// `crud/filter` via gleamgen + `cake/where` + `cake/fragment` helpers.

import cake/where

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string

import generator/gleam_format_helpers
import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext, pascal_case_field_label}
import generator/sql_types

import gleamgen/expression as gex
import gleamgen/expression/case_ as gcase
import gleamgen/expression/constructor as gcon
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/types as gtypes
import gleamgen/types/variant as gvariant

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let fl = ctx.filterable_name
  let fe = ctx.field_enum_name
  let structure_exposing = structure_import_exposing(ctx)

  let fragment_mod =
    gim.new_with_exposing(
      ["cake", "fragment"],
      "literal as frag_literal, placeholder as frag_ph, prepared as frag_prepared, string as frag_string",
    )
  let where_mod = gim.new(["cake", "where"])
  let option_mod =
    gim.new_with_exposing(["gleam", "option"], "type Option, None, Some")
  let list_mod = gim.new(["gleam", "list"])
  let structure_mod =
    gim.new_with_exposing([layer, "structure"], structure_exposing)
  let filter_help_mod = gim.new(["help", "filter"])

  let w_col = gim.function1(where_mod, where.col)
  let w_int = gim.function1(where_mod, where.int)
  let w_float = gim.function1(where_mod, where.float)
  let w_eq = gim.function2(where_mod, where.eq)
  let w_gt = gim.function2(where_mod, where.gt)
  let w_not = gim.function1(where_mod, where.not)
  let w_and = gim.function1(where_mod, where.and)
  let w_or = gim.function1(where_mod, where.or)
  let w_fragment = gim.function1(where_mod, where.fragment)

  let list_map = gim.function2(list_mod, list.map)

  let frag_lit = gex.raw("frag_literal")
  let frag_prep = gex.raw("frag_prepared")
  let frag_str = gex.raw("frag_string")
  let frag_ph = gex.raw("frag_ph")

  let concat_str = fn(parts: List(gex.Expression(String))) -> gex.Expression(String) {
    let assert [first, ..rest] = parts
    list.fold(rest, first, fn(acc, p) { gex.concat_string(acc, p) })
  }

  let filter_alias_type =
    gtypes.function1(
      gtypes.raw(fl),
      gtypes.custom_type(Some("filter"), "BoolExpr", [
        gtypes.raw("NumRefOrValue"),
        gtypes.raw("StringRefOrValue"),
      ]),
    )

  let opt_filter_t =
    gtypes.custom_type(None, "Option", [gtypes.raw("Filter")])
  let sort_param_t =
    gtypes.custom_type(None, "Option", [
      gtypes.custom_type(Some("filter"), "SortOrder", [gtypes.raw(fe)]),
    ])
  let filter_arg_ret =
    gtypes.custom_type(Some("filter"), "FilterArg", [
      gtypes.raw(fl),
      gtypes.raw("NumRefOrValue"),
      gtypes.raw("StringRefOrValue"),
      gtypes.raw(fe),
    ])

  let filter_arg_fn =
    gfun.new2(
      gparam.new("nullable_filter", opt_filter_t),
      gparam.new("sort", sort_param_t),
      filter_arg_ret,
      fn(nullable_filter_ex, sort_ex) {
        gcase.new(nullable_filter_ex)
        |> gcase.with_pattern(gpat.option_some(gpat.variable("f")), fn(f) {
          gex.call2(gex.raw("filter.FilterArg"), f, sort_ex)
        })
        |> gcase.with_pattern(gpat.option_none(), fn(_) {
          gex.call1(gex.raw("filter.NoFilter"), sort_ex)
        })
        |> gcase.build_expression()
      },
    )

  let filterable_field_exprs = {
    let schema_exprs =
      list.map(ctx.fields, fn(pair) {
        let #(label, typ) = pair
        case sql_types.filter_is_string_column(typ) {
          True ->
            gex.call1(
              gex.raw("StringRef"),
              gex.raw(pascal_case_field_label(label) <> "String"),
            )
          False ->
            gex.call1(
              gex.raw("NumRef"),
              gex.raw(pascal_case_field_label(label) <> "Int"),
            )
        }
      })
    let system_exprs = [
      gex.call1(gex.raw("NumRef"), gex.raw("IdInt")),
      gex.call1(gex.raw("NumRef"), gex.raw("CreatedAtInt")),
      gex.call1(gex.raw("NumRef"), gex.raw("UpdatedAtInt")),
      gex.call1(gex.raw("NumRef"), gex.raw("DeletedAtInt")),
    ]
    list.append(schema_exprs, system_exprs)
  }

  let filterable_refs_fn =
    gfun.new0(gtypes.raw(fl), fn() {
      gex.call_dynamic(
        gex.raw(fl),
        list.map(filterable_field_exprs, gex.to_dynamic),
      )
    })

  let num_ref_int_pat = fn(label: String) {
    let inner =
      gpat.from_constructor0(
        gcon.new(
          gvariant.new(pascal_case_field_label(label) <> "Int")
          |> gvariant.to_dynamic,
        ),
      )
    gpat.from_constructor1(
      gcon.new(
        gvariant.new("NumRef")
        |> gvariant.with_argument(None, gtypes.dynamic())
        |> gvariant.to_dynamic,
      ),
      inner,
    )
  }

  let num_operand_fn = {
    let where_value_t = gtypes.custom_type(Some("where"), "WhereValue", [])
    let op_t = gtypes.raw("NumRefOrValue")
    let case_on_op = fn(subject) {
      let with_col = fn(col: String) {
        gex.call1(w_col, gex.string(col))
      }
      let schema_cases =
        list.map(numeric_fields(ctx), fn(pair) {
          let #(label, _) = pair
          #(num_ref_int_pat(label), fn(_) { with_col(label) })
        })
      let system_labels = ["id", "created_at", "updated_at", "deleted_at"]
      let system_suffixes = ["IdInt", "CreatedAtInt", "UpdatedAtInt", "DeletedAtInt"]
      let system_cases =
        list.zip(system_labels, system_suffixes)
        |> list.map(fn(z) {
          let #(col, suffix) = z
          let inner =
            gpat.from_constructor0(
              gcon.new(gvariant.new(suffix) |> gvariant.to_dynamic),
            )
          let pat =
            gpat.from_constructor1(
              gcon.new(
                gvariant.new("NumRef")
                |> gvariant.with_argument(None, gtypes.dynamic())
                |> gvariant.to_dynamic,
              ),
              inner,
            )
          #(pat, fn(_) { with_col(col) })
        })
      let int_val_pat =
        gpat.from_constructor1(
          gcon.new(
            gvariant.new("IntVal")
            |> gvariant.with_argument(None, gtypes.dynamic())
            |> gvariant.to_dynamic,
          ),
          gpat.variable("v"),
        )
      let float_val_pat =
        gpat.from_constructor1(
          gcon.new(
            gvariant.new("FloatVal")
            |> gvariant.with_argument(None, gtypes.dynamic())
            |> gvariant.to_dynamic,
          ),
          gpat.variable("v"),
        )
      let ref_cases = list.append(schema_cases, system_cases)
      let case_after_refs =
        list.fold(ref_cases, gcase.new(subject), fn(c, arm) {
          let #(pat, h) = arm
          gcase.with_pattern(c, pat, h)
        })
      case_after_refs
      |> gcase.with_pattern(int_val_pat, fn(v) { gex.call1(w_int, v) })
      |> gcase.with_pattern(float_val_pat, fn(v) { gex.call1(w_float, v) })
      |> gcase.build_expression()
    }
    gfun.new1(
      gparam.new("op", op_t),
      where_value_t,
      fn(op_ex) { case_on_op(op_ex) },
    )
  }

  let string_ref_string_pat = fn(label: String) {
    let inner =
      gpat.from_constructor0(
        gcon.new(
          gvariant.new(pascal_case_field_label(label) <> "String")
          |> gvariant.to_dynamic,
        ),
      )
    gpat.from_constructor1(
      gcon.new(
        gvariant.new("StringRef")
        |> gvariant.with_argument(None, gtypes.dynamic())
        |> gvariant.to_dynamic,
      ),
      inner,
    )
  }

  let string_operand_fn = {
    let bool_string = gtypes.tuple2(gtypes.bool, gtypes.string)
    let op_t = gtypes.raw("StringRefOrValue")
    let schema_cases =
      list.map(string_fields(ctx), fn(pair) {
        let #(label, _) = pair
        #(
          string_ref_string_pat(label),
          fn(_) { gex.tuple2(gex.bool(True), gex.string(label)) },
        )
      })
    let string_value_pat =
      gpat.from_constructor1(
        gcon.new(
          gvariant.new("StrVal")
          |> gvariant.with_argument(None, gtypes.dynamic())
          |> gvariant.to_dynamic,
        ),
        gpat.variable("s"),
      )
    gfun.new1(
      gparam.new("op", op_t),
      bool_string,
      fn(op_ex) {
        let after_schema =
          list.fold(schema_cases, gcase.new(op_ex), fn(c, arm) {
            let #(pat, h) = arm
            gcase.with_pattern(c, pat, h)
          })
        after_schema
        |> gcase.with_pattern(string_value_pat, fn(s) {
          gex.tuple2(gex.bool(False), s)
        })
        |> gcase.build_expression()
      },
    )
  }

  let instr_where_fn = {
    let bool_string = gtypes.tuple2(gtypes.bool, gtypes.string)
    let where_ret = gtypes.custom_type(Some("where"), "Where", [])
    gfun.new2(
      gparam.new("haystack", bool_string),
      gparam.new("needle", bool_string),
      where_ret,
      fn(haystack, needle) {
        gcase.new(gex.tuple2(haystack, needle))
        |> gcase.with_pattern(
          gpat.tuple2(
            gpat.tuple2(gpat.bool_literal(True), gpat.variable("hc")),
            gpat.tuple2(gpat.bool_literal(True), gpat.variable("nc")),
          ),
          fn(pair) {
            let #(#(_, hc), #(_, nc)) = pair
            let template =
              concat_str([
                gex.string("instr("),
                hc,
                gex.string(", "),
                nc,
                gex.string(") = 0"),
              ])
            gex.call1(w_fragment, gex.call1(frag_lit, template))
          },
        )
        |> gcase.with_pattern(
          gpat.tuple2(
            gpat.tuple2(gpat.bool_literal(True), gpat.variable("hc")),
            gpat.tuple2(gpat.bool_literal(False), gpat.variable("nv")),
          ),
          fn(pair) {
            let #(#(_, hc), #(_, nv)) = pair
            let sql =
              concat_str([
                gex.string("instr("),
                hc,
                gex.string(", "),
                frag_ph,
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(
                frag_prep,
                sql,
                gex.list([gex.call1(frag_str, nv)]),
              )
            gex.call1(w_fragment, prepared)
          },
        )
        |> gcase.with_pattern(
          gpat.tuple2(
            gpat.tuple2(gpat.bool_literal(False), gpat.variable("hv")),
            gpat.tuple2(gpat.bool_literal(True), gpat.variable("nc")),
          ),
          fn(pair) {
            let #(#(_, hv), #(_, nc)) = pair
            let sql =
              concat_str([
                gex.string("instr("),
                frag_ph,
                gex.string(", "),
                nc,
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(
                frag_prep,
                sql,
                gex.list([gex.call1(frag_str, hv)]),
              )
            gex.call1(w_fragment, prepared)
          },
        )
        |> gcase.with_pattern(
          gpat.tuple2(
            gpat.tuple2(gpat.bool_literal(False), gpat.variable("hv")),
            gpat.tuple2(gpat.bool_literal(False), gpat.variable("nv")),
          ),
          fn(pair) {
            let #(#(_, hv), #(_, nv)) = pair
            let sql =
              concat_str([
                gex.string("instr("),
                frag_ph,
                gex.string(", "),
                frag_ph,
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(
                frag_prep,
                sql,
                gex.list([
                  gex.call1(frag_str, hv),
                  gex.call1(frag_str, nv),
                ]),
              )
            gex.call1(w_fragment, prepared)
          },
        )
        |> gcase.build_expression()
      },
    )
  }

  let b = gex.raw("bool_expr_where")
  let n = gex.raw("num_operand_where_value")
  let s = gex.raw("string_operand_part")
  let i = gex.raw("instr_where")
  let one = gex.call1(w_int, gex.int(1))
  let zero = gex.call1(w_int, gex.int(0))

  let bool_expr_fn = {
    let expr_t =
      gtypes.custom_type(Some("filter"), "BoolExpr", [
        gtypes.raw("NumRefOrValue"),
        gtypes.raw("StringRefOrValue"),
      ])
    let where_t = gtypes.custom_type(Some("where"), "Where", [])
    let p0 = fn(name: String) {
      gpat.from_constructor0(gcon.new(gvariant.new(name) |> gvariant.to_dynamic))
    }
    let p1 = fn(name: String, var: String) {
      gpat.from_constructor1(
        gcon.new(
          gvariant.new(name)
          |> gvariant.with_argument(None, gtypes.dynamic())
          |> gvariant.to_dynamic,
        ),
        gpat.variable(var),
      )
    }
    let p2 = fn(name: String, a: String, b: String) {
      gpat.from_constructor2(
        gcon.new(
          gvariant.new(name)
          |> gvariant.with_argument(None, gtypes.dynamic())
          |> gvariant.with_argument(None, gtypes.dynamic())
          |> gvariant.to_dynamic,
        ),
        gpat.variable(a),
        gpat.variable(b),
      )
    }
    let p_and_or_list = fn(filter_name: String) {
      gpat.from_constructor1(
        gcon.new(
          gvariant.new(filter_name)
          |> gvariant.with_argument(None, gtypes.dynamic())
          |> gvariant.to_dynamic,
        ),
        gpat.list_spread("wheres") |> gpat.to_dynamic,
      )
    }
    gfun.new1(
      gparam.new("expr", expr_t),
      where_t,
      fn(expr_ex) {
        gcase.new(expr_ex)
        |> gcase.with_pattern(p0("filter.LiteralTrue"), fn(_) {
          gex.call2(w_eq, one, one)
        })
        |> gcase.with_pattern(p0("filter.LiteralFalse"), fn(_) {
          gex.call2(w_eq, one, zero)
        })
        |> gcase.with_pattern(p1("filter.Not", "expr"), fn(expr) {
          gex.call1(w_not, gex.call1(b, expr))
        })
        |> gcase.with_pattern(p_and_or_list("filter.And"), fn(_) {
          gex.call1(
            w_and,
            gex.call2(list_map, gex.raw("wheres"), b),
          )
        })
        |> gcase.with_pattern(p_and_or_list("filter.Or"), fn(_) {
          gex.call1(
            w_or,
            gex.call2(list_map, gex.raw("wheres"), b),
          )
        })
        |> gcase.with_pattern(p2("filter.Gt", "left", "right"), fn(pair) {
          let #(left, right) = pair
          gex.call2(w_gt, gex.call1(n, left), gex.call1(n, right))
        })
        |> gcase.with_pattern(p2("filter.Eq", "left", "right"), fn(pair) {
          let #(left, right) = pair
          gex.call2(w_eq, gex.call1(n, left), gex.call1(n, right))
        })
        |> gcase.with_pattern(p2("filter.Ne", "left", "right"), fn(pair) {
          let #(left, right) = pair
          gex.call1(
            w_not,
            gex.call2(w_eq, gex.call1(n, left), gex.call1(n, right)),
          )
        })
        |> gcase.with_pattern(p2("filter.NotContains", "haystack", "needle"), fn(pair) {
          let #(haystack, needle) = pair
          gex.call2(i, gex.call1(s, haystack), gex.call1(s, needle))
        })
        |> gcase.build_expression()
      },
    )
  }

  gleamgen_emit.render_module(
    gmod.with_import(fragment_mod, fn(_) {
      use _ <- gmod.with_import(where_mod)
      use _ <- gmod.with_import(option_mod)
      use _ <- gmod.with_import(list_mod)
      use _ <- gmod.with_import(structure_mod)
      use _ <- gmod.with_import(filter_help_mod)
      gmod.with_type_alias(
        gleamgen_emit.pub_def("Filter"),
        filter_alias_type,
        fn(_) {
          use _ <- gmod.with_function(
            gleamgen_emit.pub_def("filter_arg"),
            filter_arg_fn,
          )
          use _ <- gmod.with_function(
            gleamgen_emit.pub_def("filterable_refs"),
            filterable_refs_fn,
          )
          use _ <- gmod.with_function(
            gdef.new("num_operand_where_value"),
            num_operand_fn,
          )
          use _ <- gmod.with_function(
            gdef.new("string_operand_part"),
            string_operand_fn,
          )
          use _ <- gmod.with_function(gdef.new("instr_where"), instr_where_fn)
          gmod.with_function(
            gleamgen_emit.pub_def("bool_expr_where"),
            bool_expr_fn,
            fn(_) { gmod.eof() },
          )
        },
      )
    }),
  )
}

fn structure_import_exposing(ctx: SchemaContext) -> String {
  let type_line =
    "type "
    <> ctx.field_enum_name
    <> ", type "
    <> ctx.filterable_name
    <> ", type NumRefOrValue, type StringRefOrValue,"
  let value_items = sorted_value_constructor_names(ctx)
  let value_lines =
    gleam_format_helpers.comma_wrap_lines(
      "  ",
      value_items,
      gleam_format_helpers.import_list_max_col,
    )
  type_line <> "\n" <> value_lines
}

fn sorted_value_constructor_names(ctx: SchemaContext) -> List(String) {
  let schema_nums =
    list.map(numeric_fields(ctx), fn(pair) {
      pascal_case_field_label(pair.0) <> "Int"
    })
  let system_nums =
    list.map(["CreatedAt", "DeletedAt", "Id", "UpdatedAt"], fn(s) { s <> "Int" })
  let schema_strs =
    list.map(string_fields(ctx), fn(pair) {
      pascal_case_field_label(pair.0) <> "String"
    })
  let refs = ["NumRef", "IntVal", "FloatVal", "StringRef", "StrVal"]
  list.append(schema_nums, system_nums)
  |> list.append(schema_strs)
  |> list.append([ctx.filterable_name])
  |> list.append(refs)
  |> list.sort(by: string.compare)
}

fn numeric_fields(ctx: SchemaContext) -> List(#(String, glance.Type)) {
  list.filter(ctx.fields, fn(p) { !sql_types.filter_is_string_column(p.1) })
}

fn string_fields(ctx: SchemaContext) -> List(#(String, glance.Type)) {
  list.filter(ctx.fields, fn(p) { sql_types.filter_is_string_column(p.1) })
}
