import cake/delete as cake_delete
import cake/where as cake_where
import gleam/dynamic/decode as dynamic_decode
import gleam/list
import gleam/option.{Some}
import gleam/result as gleam_result

import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext}

import gleamgen/expression as gex
import gleamgen/expression/block as gblock
import gleamgen/expression/case_ as gcase
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/module as gmod
import gleamgen/types as gtypes

import help/cake_sql_exec

pub fn generate(ctx: SchemaContext) -> String {
  let table = ctx.table
  let cake_delete_mod = gim.new_with_alias(["cake", "delete"], "cake_delete")
  let where_mod = gim.new(["cake", "where"])
  let decode_mod = gim.new(["gleam", "dynamic", "decode"])
  let list_mod = gim.new(["gleam", "list"])
  let result_mod = gim.new(["gleam", "result"])
  let sqlight_mod = gim.new(["sqlight"])
  let exec_mod = gim.new(["help", "cake_sql_exec"])

  let cd_new = gim.function0(cake_delete_mod, cake_delete.new)
  let cd_table = gim.function2(cake_delete_mod, cake_delete.table)
  let cd_where = gim.function2(cake_delete_mod, cake_delete.where)
  let cd_to_q = gim.function1(cake_delete_mod, cake_delete.to_query)

  let w_eq = gim.function2(where_mod, cake_where.eq)
  let w_col = gim.function1(where_mod, cake_where.col)
  let w_int = gim.function1(where_mod, cake_where.int)
  let w_in = gim.function2(where_mod, cake_where.in)

  let list_map = gim.function2(list_mod, list.map)
  let list_is_empty = gim.function1(list_mod, list.is_empty)
  let decode_success = gim.function1(decode_mod, dynamic_decode.success)
  let result_try = gim.function2(result_mod, gleam_result.try)
  let run_write = gim.function3(exec_mod, cake_sql_exec.run_write_query)

  let conn_t = gtypes.custom_type(Some("sqlight"), "Connection", [])
  let err_t = gtypes.custom_type(Some("sqlight"), "Error", [])
  let ret_t = gtypes.result(gtypes.nil, err_t)

  let delete_one_fn =
    gfun.new2(
      gparam.new("conn", conn_t),
      gparam.new("id", gtypes.int),
      ret_t,
      fn(conn, id) {
        let id_eq =
          gex.call2(
            w_eq,
            gex.call1(w_col, gex.string("id")),
            gex.call1(w_int, id),
          )
        let q_expr =
          gex.call1(
            cd_to_q,
            gex.call2(
              cd_where,
              gex.call2(cd_table, gex.call0(cd_new), gex.string(table)),
              id_eq,
            ),
          )
        let decode_nil = gex.call1(decode_success, gex.nil())
        let try_inner =
          gblock.with_let_declaration("q", q_expr, fn(q) {
            gex.call3(run_write, q, decode_nil, conn)
          })
        gblock.with_use1(
          gblock.use_function1(result_try, try_inner),
          "_",
          fn(_) { gex.ok(gex.nil()) },
        )
      },
    )

  let delete_many_fn =
    gfun.new2(
      gparam.new("conn", conn_t),
      gparam.new("ids", gtypes.list(gtypes.int)),
      ret_t,
      fn(conn, ids) {
        let in_clause =
          gex.call2(
            w_in,
            gex.call1(w_col, gex.string("id")),
            gex.call2(list_map, ids, w_int),
          )
        let q_expr =
          gex.call1(
            cd_to_q,
            gex.call2(
              cd_where,
              gex.call2(cd_table, gex.call0(cd_new), gex.string(table)),
              in_clause,
            ),
          )
        let decode_nil = gex.call1(decode_success, gex.nil())
        let try_inner_many =
          gblock.with_let_declaration("q", q_expr, fn(q) {
            gex.call3(run_write, q, decode_nil, conn)
          })
        let try_cont =
          gfun.anonymous(
            gfun.new1(
              gparam.new("_", gtypes.dynamic()),
              ret_t,
              fn(_) { gex.ok(gex.nil()) },
            ),
          )
        let false_branch = gex.call2(result_try, try_inner_many, try_cont)
        gcase.new(gex.call1(list_is_empty, ids))
        |> gcase.with_pattern(gpat.bool_literal(True), fn(_) {
          gex.ok(gex.nil())
        })
        |> gcase.with_pattern(gpat.bool_literal(False), fn(_) { false_branch })
        |> gcase.build_expression()
      },
    )

  gleamgen_emit.render_module(
    gmod.with_import(cake_delete_mod, fn(_) {
      gmod.with_import(where_mod, fn(_) {
        gmod.with_import(decode_mod, fn(_) {
          gmod.with_import(list_mod, fn(_) {
            gmod.with_import(result_mod, fn(_) {
              gmod.with_import(sqlight_mod, fn(_) {
                gmod.with_import(exec_mod, fn(_) {
                  gmod.with_function(gleamgen_emit.pub_def("delete_one"), delete_one_fn, fn(_) {
                    gmod.with_function(
                      gleamgen_emit.pub_def("delete_many"),
                      delete_many_fn,
                      fn(_) { gmod.eof() },
                    )
                  })
                })
              })
            })
          })
        })
      })
    }),
  )
}
