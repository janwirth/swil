//// Gleamgen-built `cake/select` and `cake/where` chains for generated read modules.

import cake/select
import cake/where

import gleam/list

import gleamgen/expression as gex
import gleamgen/import_ as gim
import gleamgen/render as grender

fn rctx() {
  grender.default_context()
}

fn rex(e: gex.Expression(t)) -> String {
  gex.render(e, rctx()) |> grender.to_string()
}

fn select_mod() {
  gim.new(["cake", "select"])
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

fn w_and() {
  gim.function1(where_mod(), where.and)
}

fn w_is_null() {
  gim.function1(where_mod(), where.is_null)
}

fn cake_sql_run_read() {
  gex.unchecked_ident("cake_sql_exec.run_read_query")
}

pub fn render_read_one_try_body(
  table: String,
  cols: List(String),
  decoder_fn: String,
) -> String {
  let sm = select_mod()
  let s_new = gim.function0(sm, select.new)
  let s_from = gim.function2(sm, select.from_table)
  let s_cols = gim.function2(sm, select.select_cols)
  let s_where = gim.function2(sm, select.where)
  let s_to_q = gim.function1(sm, select.to_query)
  let col_list = list.map(cols, gex.string)
  let sel =
    gex.call2(
      s_cols,
      gex.call2(s_from, gex.call0(s_new), gex.string(table)),
      gex.list(col_list),
    )
  let id_eq =
    gex.call2(
      w_eq(),
      gex.call1(w_col(), gex.string("id")),
      gex.call1(w_int(), gex.unchecked_ident("id")),
    )
  let deleted_null = gex.call1(w_is_null(), gex.call1(w_col(), gex.string("deleted_at")))
  let wh = gex.call1(w_and(), gex.list([id_eq, deleted_null]))
  let sel_w = gex.call2(s_where, sel, wh)
  let q = gex.call1(s_to_q, sel_w)
  let decoder_call = gex.call0(gex.unchecked_ident(decoder_fn))
  let full =
    gex.call_unchecked(cake_sql_run_read(), [
      q |> gex.to_unchecked,
      decoder_call |> gex.to_unchecked,
      gex.unchecked_ident("conn"),
    ])
  rex(full)
}

pub fn render_read_many_base_select_where(table: String, cols: List(String)) -> String {
  let sm = select_mod()
  let s_new = gim.function0(sm, select.new)
  let s_from = gim.function2(sm, select.from_table)
  let s_cols = gim.function2(sm, select.select_cols)
  let s_where = gim.function2(sm, select.where)
  let col_list = list.map(cols, gex.string)
  let sel =
    gex.call2(
      s_cols,
      gex.call2(s_from, gex.call0(s_new), gex.string(table)),
      gex.list(col_list),
    )
  let deleted_null = gex.call1(w_is_null(), gex.call1(w_col(), gex.string("deleted_at")))
  let filter_call =
    gex.call1(
      gex.unchecked_ident("read_many_filter_where"),
      gex.unchecked_ident("arg"),
    )
  let wh = gex.call1(w_and(), gex.list([deleted_null, filter_call]))
  rex(gex.call2(s_where, sel, wh))
}
