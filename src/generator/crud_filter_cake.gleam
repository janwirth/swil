//// Gleamgen-built [cake/where](https://hexdocs.pm/cake/cake/where.html) and
//// `cake/fragment` expressions for generated crud filter modules.

import cake/where

import gleam/list
import gleam/option.{Some}
import gleam/string

import gleamgen/expression as gex
import gleamgen/expression/case_ as gcase
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/matcher as gmatch
import gleamgen/render as grender
import gleamgen/types as gtypes

fn rctx() {
  grender.default_context()
}

fn rex(e: gex.Expression(t)) -> String {
  gex.render(e, rctx()) |> grender.to_string()
}

fn where_mod() {
  gim.new(["cake", "where"])
}

fn w_col() {
  gim.function1(where_mod(), where.col)
}

fn w_int() {
  gim.function1(where_mod(), where.int)
}

fn w_eq() {
  gim.function2(where_mod(), where.eq)
}

fn w_gt() {
  gim.function2(where_mod(), where.gt)
}

fn w_not() {
  gim.function1(where_mod(), where.not)
}

fn w_and() {
  gim.function1(where_mod(), where.and)
}

fn w_or() {
  gim.function1(where_mod(), where.or)
}

fn w_fragment() {
  gim.function1(where_mod(), where.fragment)
}

fn frag_lit() {
  gex.unchecked_ident("frag_literal")
}

fn frag_prep() {
  gex.unchecked_ident("frag_prepared")
}

fn frag_str() {
  gex.unchecked_ident("frag_string")
}

fn frag_ph() {
  gex.unchecked_ident("frag_ph")
}

fn concat_str(parts: List(gex.Expression(String))) -> gex.Expression(String) {
  let assert [first, ..rest] = parts
  list.fold(rest, first, fn(acc, p) { gex.concat_string(acc, p) })
}

pub fn render_where_col(column: String) -> String {
  rex(gex.call1(w_col(), gex.string(column)))
}

pub fn render_where_int_v() -> String {
  rex(gex.call1(w_int(), gex.unchecked_ident("v")))
}

pub fn render_instr_where_fn() -> String {
  let bool_string = gtypes.tuple2(gtypes.bool, gtypes.string)
  let where_ret = gtypes.custom_type(Some("where"), "Where", [])
  let f =
    gfun.new2(
      #("left", bool_string),
      #("right", bool_string),
      where_ret,
      fn(left, right) {
        gcase.new(gex.tuple2(left, right))
        |> gcase.with_matcher(
          gmatch.tuple2(
            gmatch.tuple2(gmatch.bool_literal(True), gmatch.variable("lc")),
            gmatch.tuple2(gmatch.bool_literal(True), gmatch.variable("rc")),
          ),
          fn(pair) {
            let #(#(_, lc), #(_, rc)) = pair
            let template =
              concat_str([
                gex.string("instr("),
                lc,
                gex.string(", "),
                rc,
                gex.string(") = 0"),
              ])
            gex.call1(w_fragment(), gex.call1(frag_lit(), template))
          },
        )
        |> gcase.with_matcher(
          gmatch.tuple2(
            gmatch.tuple2(gmatch.bool_literal(True), gmatch.variable("lc")),
            gmatch.tuple2(gmatch.bool_literal(False), gmatch.variable("rv")),
          ),
          fn(pair) {
            let #(#(_, lc), #(_, rv)) = pair
            let sql =
              concat_str([
                gex.string("instr("),
                lc,
                gex.string(", "),
                frag_ph(),
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(frag_prep(), sql, gex.list([gex.call1(frag_str(), rv)]))
            gex.call1(w_fragment(), prepared)
          },
        )
        |> gcase.with_matcher(
          gmatch.tuple2(
            gmatch.tuple2(gmatch.bool_literal(False), gmatch.variable("lv")),
            gmatch.tuple2(gmatch.bool_literal(True), gmatch.variable("rc")),
          ),
          fn(pair) {
            let #(#(_, lv), #(_, rc)) = pair
            let sql =
              concat_str([
                gex.string("instr("),
                frag_ph(),
                gex.string(", "),
                rc,
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(frag_prep(), sql, gex.list([gex.call1(frag_str(), lv)]))
            gex.call1(w_fragment(), prepared)
          },
        )
        |> gcase.with_matcher(
          gmatch.tuple2(
            gmatch.tuple2(gmatch.bool_literal(False), gmatch.variable("lv")),
            gmatch.tuple2(gmatch.bool_literal(False), gmatch.variable("rv")),
          ),
          fn(pair) {
            let #(#(_, lv), #(_, rv)) = pair
            let sql =
              concat_str([
                gex.string("instr("),
                frag_ph(),
                gex.string(", "),
                frag_ph(),
                gex.string(") = 0"),
              ])
            let prepared =
              gex.call2(
                frag_prep(),
                sql,
                gex.list([gex.call1(frag_str(), lv), gex.call1(frag_str(), rv)]),
              )
            gex.call1(w_fragment(), prepared)
          },
        )
        |> gcase.build_expression()
      },
    )
  string.concat([
    grender.to_string(gfun.render(f, rctx(), Some("instr_where"))),
    "\n",
  ])
}

pub fn render_bool_expr_where_case_lines() -> String {
  let b = gex.unchecked_ident("bool_expr_where")
  let n = gex.unchecked_ident("num_operand_where_value")
  let s = gex.unchecked_ident("string_operand_part")
  let i = gex.unchecked_ident("instr_where")
  let one = gex.call1(w_int(), gex.int(1))
  let zero = gex.call1(w_int(), gex.int(0))
  string.concat([
    "    filter.LiteralTrue -> ",
    rex(gex.call2(w_eq(), one, one)),
    "\n    filter.LiteralFalse -> ",
    rex(gex.call2(w_eq(), one, zero)),
    "\n    filter.Not(inner) -> ",
    rex(gex.call1(w_not(), gex.call1(b, gex.unchecked_ident("inner")))),
    "\n    filter.And(left, right) ->\n      ",
    rex(
      gex.call1(
        w_and(),
        gex.list([
          gex.call1(b, gex.unchecked_ident("left")),
          gex.call1(b, gex.unchecked_ident("right")),
        ]),
      ),
    ),
    "\n    filter.Or(left, right) ->\n      ",
    rex(
      gex.call1(
        w_or(),
        gex.list([
          gex.call1(b, gex.unchecked_ident("left")),
          gex.call1(b, gex.unchecked_ident("right")),
        ]),
      ),
    ),
    "\n    filter.Gt(left, right) ->\n      ",
    rex(
      gex.call2(
        w_gt(),
        gex.call1(n, gex.unchecked_ident("left")),
        gex.call1(n, gex.unchecked_ident("right")),
      ),
    ),
    "\n    filter.Eq(left, right) ->\n      ",
    rex(
      gex.call2(
        w_eq(),
        gex.call1(n, gex.unchecked_ident("left")),
        gex.call1(n, gex.unchecked_ident("right")),
      ),
    ),
    "\n    filter.Ne(left, right) ->\n      ",
    rex(
      gex.call1(
        w_not(),
        gex.call2(
          w_eq(),
          gex.call1(n, gex.unchecked_ident("left")),
          gex.call1(n, gex.unchecked_ident("right")),
        ),
      ),
    ),
    "\n    filter.NotContains(left, right) ->\n      ",
    rex(
      gex.call2(
        i,
        gex.call1(s, gex.unchecked_ident("left")),
        gex.call1(s, gex.unchecked_ident("right")),
      ),
    ),
    "\n",
  ])
}
