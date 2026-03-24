//// Generated `read` modules: `cake/select` + `cake/where` via gleamgen.

import cake/select
import cake/where

import gleam/list
import gleam/option as opt
import gleam/result as gleam_result

import generator/gleam_format_helpers
import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext}

import gleamgen/expression as gex
import gleamgen/expression/block as gblock
import gleamgen/expression/case_ as gcase
import gleamgen/expression/constructor as gcon
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/render as grender
import gleamgen/types as gtypes
import gleamgen/types/variant as gvariant

import help/cake_sql_exec

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let fl = ctx.filterable_name
  let fe = ctx.field_enum_name
  let row = ctx.row_name
  let table = ctx.table
  let cols = select_column_names(ctx)
  let decoder = ctx.singular <> "_row_decoder"
  let read_type_block = [
    "type " <> fe,
    "type " <> row,
    "type " <> fl,
    "type NumRefOrValue",
  ]
  let read_value_block = ["type StringRefOrValue", decoder]
  let structure_exposing =
    gleam_format_helpers.comma_wrap_lines(
      "  ",
      read_type_block,
      gleam_format_helpers.import_list_max_col,
    )
    <> "\n"
    <> gleam_format_helpers.comma_wrap_lines(
      "  ",
      read_value_block,
      gleam_format_helpers.import_list_max_col,
    )

  let sel_mod = gim.new_predefined(["cake", "select"])
  let where_mod = gim.new_predefined(["cake", "where"])
  let option_mod =
    gim.new_with_exposing(["gleam", "option"], "type Option, None, Some")
  let result_mod = gim.new(["gleam", "result"])
  let sqlight_mod = gim.new(["sqlight"])
  let structure_mod =
    gim.new_with_exposing([layer, "structure"], structure_exposing)
  let filter_mod = gim.new_predefined(["help", "filter"])
  let exec_mod = gim.new(["help", "cake_sql_exec"])
  let crud_filter_mod =
    gim.new_with_alias([layer, "crud", "filter"], "crud_filter")
  let crud_sort_mod =
    gim.new_with_alias([layer, "crud", "sort"], "crud_sort")

  let result_try = gim.function2(result_mod, gleam_result.try)

  let conn_t = gtypes.custom_type(opt.Some("sqlight"), "Connection", [])
  let err_t = gtypes.custom_type(opt.Some("sqlight"), "Error", [])
  let row_t = gtypes.raw(row)
  let opt_row =
    gtypes.custom_type(opt.None, "Option", [row_t |> gtypes.to_dynamic])
  let read_one_ret = gtypes.result(opt_row, err_t)
  let list_row_t = gtypes.list(row_t)
  let read_many_ret = gtypes.result(list_row_t, err_t)

  let filter_arg_t =
    gtypes.custom_type(opt.Some("filter"), "FilterArg", [
      gtypes.raw(fl),
      gtypes.raw("NumRefOrValue"),
      gtypes.raw("StringRefOrValue"),
      gtypes.raw(fe),
    ])
  let where_t = gtypes.custom_type(opt.Some("where"), "Where", [])

  let read_one_fn =
    gfun.new2(
      gparam.new("conn", conn_t),
      gparam.new("id", gtypes.int),
      read_one_ret,
      fn(_conn, _id) {
        let try_body = read_one_try_body_expression(table, cols, decoder)
        let use_try =
          gblock.use_function1(result_try, try_body)
        gblock.with_use1(use_try, "rows", fn(rows) {
          gcase.new(rows)
          |> gcase.with_pattern(gpat.list_first_discard_rest("row"), fn(row) {
            gex.ok(gex.call1(gex.raw("Some"), row))
          })
          |> gcase.with_pattern(gpat.list_empty(), fn(_) { gex.ok(gex.raw("None")) })
          |> gcase.build_expression()
        })
      },
    )

  let no_filter_pat =
    gpat.from_constructor1(
      gcon.new(
        gvariant.new("filter.NoFilter")
        |> gvariant.with_argument(opt.None, gtypes.dynamic())
        |> gvariant.to_dynamic,
      ),
      gpat.discard(),
    )
  let filter_arg_pat =
    gpat.from_constructor2(
      gcon.new(
        gvariant.new("filter.FilterArg")
        |> gvariant.with_argument(opt.None, gtypes.dynamic())
        |> gvariant.with_argument(opt.None, gtypes.dynamic())
        |> gvariant.to_dynamic,
      ),
      gpat.variable("f"),
      gpat.discard(),
    )

  let w_eq = gim.function2(where_mod, where.eq)
  let w_int = gim.function1(where_mod, where.int)

  let read_many_filter_fn =
    gfun.new1(
      gparam.new("arg", filter_arg_t),
      where_t,
      fn(arg_ex) {
        gcase.new(arg_ex)
        |> gcase.with_pattern(no_filter_pat, fn(_) {
          gex.call2(w_eq, gex.call1(w_int, gex.int(1)), gex.call1(w_int, gex.int(1)))
        })
        |> gcase.with_pattern(filter_arg_pat, fn(pair) {
          let #(f, _) = pair
          gex.call1(
            gex.raw("crud_filter.bool_expr_where"),
            gex.call1(
              f,
              gex.call0(gex.raw("crud_filter.filterable_refs")),
            ),
          )
        })
        |> gcase.build_expression()
      },
    )

  let no_filter_sort_pat =
    gpat.from_constructor1(
      gcon.new(
        gvariant.new("filter.NoFilter")
        |> gvariant.with_argument(opt.Some("sort"), gtypes.dynamic())
        |> gvariant.to_dynamic,
      ),
      gpat.variable("s"),
    )
  let filter_arg_sort_pat =
    gpat.from_constructor2(
      gcon.new(
        gvariant.new("filter.FilterArg")
        |> gvariant.with_argument(opt.None, gtypes.dynamic())
        |> gvariant.with_argument(opt.Some("sort"), gtypes.dynamic())
        |> gvariant.to_dynamic,
      ),
      gpat.discard(),
      gpat.variable("s"),
    )

  let sm = sel_mod
  let s_order_asc = gim.function2(sm, select.order_by_asc)
  let s_order_desc = gim.function2(sm, select.order_by_desc)
  let field_sql_fn = ctx.singular <> "_field_sql"
  let sort_sql = gex.raw("crud_sort." <> field_sql_fn)

  let read_many_ordered_fn =
    gfun.new1(
      gparam.new("arg", filter_arg_t),
      gtypes.dynamic(),
      fn(arg_ex) {
        let order_expr =
          gcase.new(arg_ex)
          |> gcase.with_pattern(no_filter_sort_pat, fn(s) { s })
          |> gcase.with_pattern(filter_arg_sort_pat, fn(pair) { pair.1 })
          |> gcase.build_expression()
        let base_expr =
          gex.raw(render_read_many_base_select_where(table, cols))
        gblock.with_let_declaration("order", order_expr, fn(_order) {
          gblock.with_let_declaration("base", base_expr, fn(base) {
            let asc_pat =
              gpat.from_constructor1(
                gcon.new(
                  gvariant.new("filter.Asc")
                  |> gvariant.with_argument(opt.None, gtypes.dynamic())
                  |> gvariant.to_dynamic,
                ),
                gpat.variable("f"),
              )
            let desc_pat =
              gpat.from_constructor1(
                gcon.new(
                  gvariant.new("filter.Desc")
                  |> gvariant.with_argument(opt.None, gtypes.dynamic())
                  |> gvariant.to_dynamic,
                ),
                gpat.variable("f"),
              )
            gcase.new(gex.raw("order"))
            |> gcase.with_pattern(gpat.option_none(), fn(_) { base })
            |> gcase.with_pattern(gpat.option_some(asc_pat), fn(f_expr) {
              gex.call2(s_order_asc, base, gex.call1(sort_sql, f_expr))
            })
            |> gcase.with_pattern(gpat.option_some(desc_pat), fn(f_expr) {
              gex.call2(s_order_desc, base, gex.call1(sort_sql, f_expr))
            })
            |> gcase.build_expression()
          })
        })
      },
    )

  let read_many_fn =
    gfun.new2(
      gparam.new("conn", conn_t),
      gparam.new("arg", filter_arg_t),
      read_many_ret,
      fn(conn, arg) {
        let sm2 = sel_mod
        let s_to_q = gim.function1(sm2, select.to_query)
        let run_read = gim.function3(exec_mod, cake_sql_exec.run_read_query)
        let ordered = gex.call1(gex.raw("read_many_ordered"), arg)
        let q = gex.call1(s_to_q, ordered)
        gex.call3(
          run_read,
          q,
          gex.call0(gex.raw(decoder)),
          conn,
        )
      },
    )

  gleamgen_emit.render_module(
    gmod.with_import(sel_mod, fn(_) {
      use _ <- gmod.with_import(where_mod)
      use _ <- gmod.with_import(option_mod)
      use _ <- gmod.with_import(result_mod)
      use _ <- gmod.with_import(sqlight_mod)
      use _ <- gmod.with_import(structure_mod)
      use _ <- gmod.with_import(crud_filter_mod)
      use _ <- gmod.with_import(crud_sort_mod)
      use _ <- gmod.with_import(filter_mod)
      use _ <- gmod.with_import(exec_mod)
      use _ <- gmod.with_function(gleamgen_emit.pub_def("read_one"), read_one_fn)
      use _ <- gmod.with_function(
        gdef.new("read_many_filter_where"),
        read_many_filter_fn,
      )
      use _ <- gmod.with_function(
        gdef.new("read_many_ordered"),
        read_many_ordered_fn,
      )
      gmod.with_function(
        gleamgen_emit.pub_def("read_many"),
        read_many_fn,
        fn(_) { gmod.eof() },
      )
    }),
  )
}

fn select_column_names(ctx: SchemaContext) -> List(String) {
  let rest = list.map(ctx.fields, fn(pair) { pair.0 })
  ["id", "created_at", "updated_at", "deleted_at", ..rest]
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

pub fn read_one_try_body_expression(
  table: String,
  cols: List(String),
  decoder_fn: String,
) {
  let sm = select_mod()
  let exec_mod = gim.new(["help", "cake_sql_exec"])
  let run_read = gim.function3(exec_mod, cake_sql_exec.run_read_query)
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
      gex.call1(w_int(), gex.raw("id")),
    )
  let deleted_null =
    gex.call1(w_is_null(), gex.call1(w_col(), gex.string("deleted_at")))
  let wh = gex.call1(w_and(), gex.list([id_eq, deleted_null]))
  let sel_w = gex.call2(s_where, sel, wh)
  let q = gex.call1(s_to_q, sel_w)
  let decoder_call = gex.call0(gex.raw(decoder_fn))
  gex.call3(run_read, q, decoder_call, gex.raw("conn"))
}

pub fn render_read_many_base_select_where(
  table: String,
  cols: List(String),
) -> String {
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
  let deleted_null =
    gex.call1(w_is_null(), gex.call1(w_col(), gex.string("deleted_at")))
  let filter_call =
    gex.call1(gex.raw("read_many_filter_where"), gex.raw("arg"))
  let wh = gex.call1(w_and(), gex.list([deleted_null, filter_call]))
  let e = gex.call2(s_where, sel, wh)
  let ctx = grender.default_context()
  gex.render(e, ctx) |> grender.to_string()
}
