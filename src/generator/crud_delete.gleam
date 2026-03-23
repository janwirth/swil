import cake/update as cake_update
import cake/where as cake_where
import gleam/dynamic/decode as dynamic_decode
import gleam/list
import gleam/option.{Some}
import gleam/result as gleam_result
import gleam/time/timestamp

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
  let cake_update_mod = gim.new_with_alias(["cake", "update"], "cake_update")
  let where_mod = gim.new(["cake", "where"])
  let decode_mod = gim.new(["gleam", "dynamic", "decode"])
  let list_mod = gim.new(["gleam", "list"])
  let result_mod = gim.new(["gleam", "result"])
  let timestamp_mod = gim.new(["gleam", "time", "timestamp"])
  let sqlight_mod = gim.new(["sqlight"])
  let exec_mod = gim.new(["help", "cake_sql_exec"])

  let cu_new = gim.function0(cake_update_mod, cake_update.new)
  let cu_table = gim.function2(cake_update_mod, cake_update.table)
  let cu_set = gim.function2(cake_update_mod, cake_update.set)
  let cu_set_int = gim.function2(cake_update_mod, cake_update.set_int)
  let cu_where = gim.function2(cake_update_mod, cake_update.where)
  let cu_to_q = gim.function1(cake_update_mod, cake_update.to_query)

  let w_eq = gim.function2(where_mod, cake_where.eq)
  let w_col = gim.function1(where_mod, cake_where.col)
  let w_int = gim.function1(where_mod, cake_where.int)
  let w_in = gim.function2(where_mod, cake_where.in)
  let w_and = gim.function1(where_mod, cake_where.and)
  let w_is_null = gim.function1(where_mod, cake_where.is_null)

  let list_map = gim.function2(list_mod, list.map)
  let ts_system = gim.function0(timestamp_mod, timestamp.system_time)
  let ts_to_unix_ns =
    gim.function1(timestamp_mod, timestamp.to_unix_seconds_and_nanoseconds)
  let decode_success = gim.function1(decode_mod, dynamic_decode.success)
  let result_try = gim.function2(result_mod, gleam_result.try)
  let run_write = gim.function3(exec_mod, cake_sql_exec.run_write_query)

  let conn_t = gtypes.custom_type(Some("sqlight"), "Connection", [])
  let err_t = gtypes.custom_type(Some("sqlight"), "Error", [])
  let ret_t = gtypes.result(gtypes.nil, err_t)

  let with_now_sec = fn(inner: fn(gex.Expression(Int)) -> gex.Expression(a)) {
    gblock.with_matching_let_declaration(
      gpat.tuple2(gpat.variable("now_sec"), gpat.discard()),
      gex.call1(ts_to_unix_ns, gex.call0(ts_system)),
      False,
      fn(pair) {
        let now_sec = pair.0
        inner(now_sec)
      },
    )
  }

  let deleted_null =
    gex.call1(w_is_null, gex.call1(w_col, gex.string("deleted_at")))

  let soft_update_where_from_eq = fn(id: gex.Expression(Int)) {
    gex.call1(w_and, gex.list([
      gex.call2(
        w_eq,
        gex.call1(w_col, gex.string("id")),
        gex.call1(w_int, id),
      ),
      deleted_null,
    ]))
  }

  let soft_update_where_from_ids = fn(ids: gex.Expression(List(Int))) {
    gex.call1(w_and, gex.list([
      gex.call2(
        w_in,
        gex.call1(w_col, gex.string("id")),
        gex.call2(list_map, ids, w_int),
      ),
      deleted_null,
    ]))
  }

  let to_soft_update_query = fn(where_clause: gex.Expression(cake_where.Where), now_sec: gex.Expression(Int)) {
    let u0 = gex.call2(cu_table, gex.call0(cu_new), gex.string(table))
    let u1 =
      gex.call2(
        cu_set,
        u0,
        gex.call2(cu_set_int, gex.string("deleted_at"), now_sec),
      )
    let u2 =
      gex.call2(
        cu_set,
        u1,
        gex.call2(cu_set_int, gex.string("updated_at"), now_sec),
      )
    let u3 = gex.call2(cu_where, u2, where_clause)
    gex.call1(cu_to_q, u3)
  }

  let delete_one_fn =
    gfun.new2(
      gparam.new("conn", conn_t),
      gparam.new("id", gtypes.int),
      ret_t,
      fn(conn, id) {
        let where_cl = soft_update_where_from_eq(id)
        let try_inner =
          with_now_sec(fn(now_sec) {
            let q_expr = to_soft_update_query(where_cl, now_sec)
            gblock.with_let_declaration("q", q_expr, fn(q) {
              let decode_nil = gex.call1(decode_success, gex.nil())
              gex.call3(run_write, q, decode_nil, conn)
            })
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
        let try_cont =
          gfun.anonymous(
            gfun.new1(
              gparam.new("_", gtypes.dynamic()),
              ret_t,
              fn(_) { gex.ok(gex.nil()) },
            ),
          )
        gcase.new(ids)
        |> gcase.with_pattern(gpat.list_empty(), fn(_) { gex.ok(gex.nil()) })
        |> gcase.with_pattern(gpat.list_spread("ids"), fn(ids_expr) {
          let where_cl = soft_update_where_from_ids(ids_expr)
          let try_inner_many =
            with_now_sec(fn(now_sec) {
              let q_expr = to_soft_update_query(where_cl, now_sec)
              gblock.with_let_declaration("q", q_expr, fn(q) {
                let decode_nil = gex.call1(decode_success, gex.nil())
                gex.call3(run_write, q, decode_nil, conn)
              })
            })
          gex.call2(result_try, try_inner_many, try_cont)
        })
        |> gcase.build_expression()
      },
    )

  gleamgen_emit.render_module(
    gmod.with_import(cake_update_mod, fn(_) {
      use _ <- gmod.with_import(where_mod)
      use _ <- gmod.with_import(decode_mod)
      use _ <- gmod.with_import(list_mod)
      use _ <- gmod.with_import(result_mod)
      use _ <- gmod.with_import(timestamp_mod)
      use _ <- gmod.with_import(sqlight_mod)
      use _ <- gmod.with_import(exec_mod)
      use _ <- gmod.with_function(
        gleamgen_emit.pub_def("delete_one"),
        delete_one_fn,
      )
      gmod.with_function(
        gleamgen_emit.pub_def("delete_many"),
        delete_many_fn,
        fn(_) { gmod.eof() },
      )
    }),
  )
}
