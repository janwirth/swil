import cake/update as cake_update
import cake/where as cake_where

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string

import generator/crud_read
import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext}
import generator/sql_types

import gleam/dynamic/decode as dynamic_decode
import gleam/result as gleam_result
import gleam/time/timestamp

import gleamgen/expression as gex
import gleamgen/expression/block as gblock
import gleamgen/expression/case_ as gcase
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/types as gtypes

import help/cake_sql_exec

pub fn generate(ctx: SchemaContext) -> String {
  let table = ctx.table
  let singular = ctx.singular
  let cols = update_select_column_names(ctx)
  let decoder_fn = ctx.singular <> "_row_decoder"
  let schema_path = string.split(ctx.schema_module, "/")

  let sel_mod = gim.new_predefined(["cake", "select"])
  let cake_update_mod = gim.new_with_alias(["cake", "update"], "cake_update")
  let where_mod = gim.new(["cake", "where"])
  let decode_mod = gim.new(["gleam", "dynamic", "decode"])
  let list_mod = gim.new(["gleam", "list"])
  let option_mod =
    gim.new_with_exposing(["gleam", "option"], "type Option, None, Some")
  let result_mod = gim.new(["gleam", "result"])
  let ts_mod = gim.new(["gleam", "time", "timestamp"])
  let sqlight_mod = gim.new(["sqlight"])
  let exec_mod = gim.new(["help", "cake_sql_exec"])
  let structure_mod =
    gim.new_with_exposing(
      [ctx.layer, "structure"],
      "type " <> ctx.row_name <> ", " <> decoder_fn,
    )
  let schema_mod = gim.new_with_exposing(schema_path, "type " <> ctx.type_name)

  let cu_new = gim.function0(cake_update_mod, cake_update.new)
  let cu_table = gim.function2(cake_update_mod, cake_update.table)
  let cu_set = gim.function2(cake_update_mod, cake_update.set)
  let cu_set_int = gim.function2(cake_update_mod, cake_update.set_int)
  let cu_set_float = gim.function2(cake_update_mod, cake_update.set_float)
  let cu_set_bool = gim.function2(cake_update_mod, cake_update.set_bool)
  let cu_set_string = gim.function2(cake_update_mod, cake_update.set_string)
  let cu_set_null = gim.function1(cake_update_mod, cake_update.set_null)
  let cu_where = gim.function2(cake_update_mod, cake_update.where)
  let cu_to_q = gim.function1(cake_update_mod, cake_update.to_query)

  let w_eq = gim.function2(where_mod, cake_where.eq)
  let w_col = gim.function1(where_mod, cake_where.col)
  let w_int = gim.function1(where_mod, cake_where.int)
  let w_and = gim.function1(where_mod, cake_where.and)
  let w_is_null = gim.function1(where_mod, cake_where.is_null)

  let decode_success = gim.function1(decode_mod, dynamic_decode.success)
  let result_try = gim.function2(result_mod, gleam_result.try)
  let list_try_map = gim.function2(list_mod, list.try_map)
  let ts_system = gim.function0(ts_mod, timestamp.system_time)
  let ts_to_unix =
    gim.function1(ts_mod, timestamp.to_unix_seconds_and_nanoseconds)
  let run_write = gim.function3(exec_mod, cake_sql_exec.run_write_query)

  let conn_t = gtypes.custom_type(Some("sqlight"), "Connection", [])
  let err_t = gtypes.custom_type(Some("sqlight"), "Error", [])
  let row_t = gtypes.custom_type(None, ctx.row_name, [])
  let schema_t =
    gtypes.custom_type(Some(gim.get_reference(schema_mod)), ctx.type_name, [])
  let schema_t_row = gtypes.custom_type(None, ctx.type_name, [])
  let opt_row = gtypes.custom_type(None, "Option", [gtypes.to_dynamic(row_t)])
  let ret_one = gtypes.result(opt_row, err_t)
  let ret_many = gtypes.result(gtypes.list(opt_row), err_t)

  let deleted_null =
    gex.call1(w_is_null, gex.call1(w_col, gex.string("deleted_at")))

  let field_access_raw = fn(label: String) { gex.raw(singular <> "." <> label) }

  let update_field_step = fn(
    u_ref: gex.Expression(cake_update.Update(Nil)),
    pair: #(String, glance.Type),
  ) {
    let #(label, typ) = pair
    let acc = field_access_raw(label)
    case sql_types.rendered_type(typ) {
      "Int" ->
        gex.call2(cu_set, u_ref, gex.call2(cu_set_int, gex.string(label), acc))
      "Float" ->
        gex.call2(
          cu_set,
          u_ref,
          gex.call2(
            cu_set_float,
            gex.string(label),
            gex.coerce_dynamic_unsafe(acc),
          ),
        )
      "Bool" ->
        gex.call2(
          cu_set,
          u_ref,
          gex.call2(
            cu_set_bool,
            gex.string(label),
            gex.coerce_dynamic_unsafe(acc),
          ),
        )
      "String" ->
        gex.call2(
          cu_set,
          u_ref,
          gex.call2(
            cu_set_string,
            gex.string(label),
            gex.coerce_dynamic_unsafe(acc),
          ),
        )
      "Option(Int)" ->
        gcase.new(gex.to_dynamic(acc))
        |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
          gex.call2(cu_set, u_ref, gex.call2(cu_set_int, gex.string(label), v))
        })
        |> gcase.with_pattern(gpat.option_none(), fn(_) {
          gex.call2(cu_set, u_ref, gex.call1(cu_set_null, gex.string(label)))
        })
        |> gcase.build_expression()
      "Option(Float)" ->
        gcase.new(gex.to_dynamic(acc))
        |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
          gex.call2(
            cu_set,
            u_ref,
            gex.call2(cu_set_float, gex.string(label), v),
          )
        })
        |> gcase.with_pattern(gpat.option_none(), fn(_) {
          gex.call2(cu_set, u_ref, gex.call1(cu_set_null, gex.string(label)))
        })
        |> gcase.build_expression()
      "Option(Bool)" ->
        gcase.new(gex.to_dynamic(acc))
        |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
          gex.call2(cu_set, u_ref, gex.call2(cu_set_bool, gex.string(label), v))
        })
        |> gcase.with_pattern(gpat.option_none(), fn(_) {
          gex.call2(cu_set, u_ref, gex.call1(cu_set_null, gex.string(label)))
        })
        |> gcase.build_expression()
      "Option(String)" ->
        gcase.new(gex.to_dynamic(acc))
        |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
          gex.call2(
            cu_set,
            u_ref,
            gex.call2(cu_set_string, gex.string(label), v),
          )
        })
        |> gcase.with_pattern(gpat.option_none(), fn(_) {
          gex.call2(cu_set, u_ref, gex.call1(cu_set_null, gex.string(label)))
        })
        |> gcase.build_expression()
      _ ->
        gex.call2(
          cu_set,
          u_ref,
          gex.call2(cu_set_string, gex.string(label), gex.string("")),
        )
    }
  }

  let write_try_inner = fn() {
    gblock.with_matching_let_declaration(
      gpat.tuple2(gpat.variable("now_sec"), gpat.discard()),
      gex.call1(ts_to_unix, gex.call0(ts_system)),
      False,
      fn(pair) {
        let now_sec = pair.0
        let u_table = gex.call2(cu_table, gex.call0(cu_new), gex.string(table))
        let u_after_fields = list.fold(ctx.fields, u_table, update_field_step)
        let u_with_stamp =
          gex.call2(
            cu_set,
            u_after_fields,
            gex.call2(cu_set_int, gex.string("updated_at"), now_sec),
          )
        let q_expr =
          gex.call1(
            cu_to_q,
            gex.call2(
              cu_where,
              u_with_stamp,
              gex.call1(
                w_and,
                gex.list([
                  gex.call2(
                    w_eq,
                    gex.call1(w_col, gex.string("id")),
                    gex.call1(w_int, gex.raw("id")),
                  ),
                  deleted_null,
                ]),
              ),
            ),
          )
        gex.call3(
          run_write,
          q_expr,
          gex.call1(decode_success, gex.nil()),
          gex.raw("conn"),
        )
      },
    )
  }

  let read_expr =
    crud_read.read_one_try_body_expression(table, cols, decoder_fn)

  let update_one_fn =
    gfun.new3(
      gparam.new("conn", conn_t),
      gparam.new("id", gtypes.int),
      gparam.new(singular, schema_t),
      ret_one,
      fn(_conn, _id, _sing) {
        gblock.with_use1(
          gblock.use_function1(result_try, write_try_inner()),
          "_",
          fn(_) {
            gblock.with_use1(
              gblock.use_function1(result_try, read_expr),
              "rows",
              fn(rows) {
                gcase.new(rows)
                |> gcase.with_pattern(
                  gpat.list_first_discard_rest("row"),
                  fn(row) { gex.ok(gex.call1(gex.raw("Some"), row)) },
                )
                |> gcase.with_pattern(gpat.list_empty(), fn(_) {
                  gex.ok(gex.raw("None"))
                })
                |> gcase.build_expression()
              },
            )
          },
        )
      },
    )

  let update_many_fn =
    gfun.new2(
      gparam.new("conn", conn_t),
      gparam.new("rows", gtypes.list(gtypes.tuple2(gtypes.int, schema_t_row))),
      ret_many,
      fn(conn, rows) {
        gex.call2(
          list_try_map,
          rows,
          gfun.anonymous(
            gfun.new1(
              gparam.new("row", gtypes.tuple2(gtypes.int, schema_t_row)),
              ret_one,
              fn(row_var) {
                gblock.with_matching_let_declaration(
                  gpat.tuple2(gpat.variable("id"), gpat.variable(singular)),
                  row_var,
                  False,
                  fn(pair) {
                    gex.call3(gex.raw("update_one"), conn, pair.0, pair.1)
                  },
                )
              },
            ),
          ),
        )
      },
    )

  gleamgen_emit.render_module(
    gmod.with_import(sel_mod, fn(_) {
      use _ <- gmod.with_import(cake_update_mod)
      use _ <- gmod.with_import(where_mod)
      use _ <- gmod.with_import(decode_mod)
      use _ <- gmod.with_import(list_mod)
      use _ <- gmod.with_import(option_mod)
      use _ <- gmod.with_import(result_mod)
      use _ <- gmod.with_import(ts_mod)
      use _ <- gmod.with_import(sqlight_mod)
      use _ <- gmod.with_import(structure_mod)
      use _ <- gmod.with_import(schema_mod)
      use _ <- gmod.with_import(exec_mod)
      use _ <- gmod.with_function(
        gleamgen_emit.pub_def("update_one"),
        update_one_fn,
      )
      gmod.with_function(
        gleamgen_emit.pub_def("update_many"),
        update_many_fn,
        fn(_) { gmod.eof() },
      )
    }),
  )
}

fn update_select_column_names(ctx: SchemaContext) -> List(String) {
  let rest = list.map(ctx.fields, fn(pair) { pair.0 })
  ["id", "created_at", "updated_at", "deleted_at", ..rest]
}
