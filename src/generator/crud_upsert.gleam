import cake/insert as cake_insert
import cake/select
import cake/update as cake_update
import cake/where

import glance
import gleam/list

import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext}
import generator/sql_types

import gleamgen/expression as gex
import gleamgen/expression/block as gblock
import gleamgen/expression/case_ as gcase
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/parameter as gparam
import gleamgen/pattern as gpat
import gleamgen/types as gtypes

import gleam/dynamic/decode as dynamic_decode
import gleam/option.{None, Some}
import gleam/result as gleam_result
import gleam/time/timestamp

import help/cake_sql_exec

pub fn generate(ctx: SchemaContext) -> String {
  gleamgen_emit.render_module(upsert_module(ctx))
}

fn upsert_module(ctx: SchemaContext) -> gmod.Module {
  let table = ctx.table
  let singular = ctx.singular
  let variant_name = ctx.for_upsert_variant_name
  let row_name = ctx.row_name
  let decoder_fn = ctx.singular <> "_row_decoder"

  let resource_mod =
    gim.new_with_exposing(
      [ctx.layer, "resource"],
      "type " <> ctx.for_upsert_type_name <> ", " <> ctx.for_upsert_variant_name,
    )
  let structure_mod =
    gim.new_with_exposing(
      [ctx.layer, "structure"],
      "type " <> ctx.row_name <> ", " <> decoder_fn,
    )
  let ci_mod = gim.new_with_alias(["cake", "insert"], "cake_insert")
  let cu_mod = gim.new_with_alias(["cake", "update"], "cake_update")
  let sel_mod = gim.new(["cake", "select"])
  let where_mod = gim.new(["cake", "where"])
  let decode_mod = gim.new(["gleam", "dynamic", "decode"])
  let list_mod = gim.new(["gleam", "list"])
  let option_mod = gim.new_with_exposing(["gleam", "option"], "None, Some")
  let result_mod = gim.new(["gleam", "result"])
  let ts_mod = gim.new(["gleam", "time", "timestamp"])
  let sqlight_mod = gim.new(["sqlight"])
  let exec_mod = gim.new(["help", "cake_sql_exec"])

  let ci_new = gim.function0(ci_mod, cake_insert.new)
  let ci_table = gim.function2(ci_mod, cake_insert.table)
  let ci_columns = gim.function2(ci_mod, cake_insert.columns)
  let ci_source_values = gim.function2(ci_mod, cake_insert.source_values)
  let ci_row = gim.function1(ci_mod, cake_insert.row)
  let ci_to_query = gim.function1(ci_mod, cake_insert.to_query)
  let ci_on_conflict =
    gim.function4(ci_mod, cake_insert.on_columns_conflict_update)
  let ci_string = gim.function1(ci_mod, cake_insert.string)
  let ci_int = gim.function1(ci_mod, cake_insert.int)
  let ci_bool = gim.function1(ci_mod, cake_insert.bool)
  let ci_float = gim.function1(ci_mod, cake_insert.float)
  let cu_new = gim.function0(cu_mod, cake_update.new)
  let cu_set = gim.function2(cu_mod, cake_update.set)
  let cu_set_expr = gim.function2(cu_mod, cake_update.set_expression)

  let s_new = gim.function0(sel_mod, select.new)
  let s_from = gim.function2(sel_mod, select.from_table)
  let s_cols = gim.function2(sel_mod, select.select_cols)
  let s_where = gim.function2(sel_mod, select.where)
  let s_to_q = gim.function1(sel_mod, select.to_query)

  let w_eq = gim.function2(where_mod, where.eq)
  let w_col = gim.function1(where_mod, where.col)
  let w_int = gim.function1(where_mod, where.int)
  let w_string = gim.function1(where_mod, where.string)
  let w_float = gim.function1(where_mod, where.float)
  let w_and = gim.function1(where_mod, where.and)
  let w_is_null = gim.function1(where_mod, where.is_null)
  let w_is_bool = gim.function2(where_mod, where.is_bool)

  let decode_success = gim.function1(decode_mod, dynamic_decode.success)
  let result_try = gim.function2(result_mod, gleam_result.try)
  let result_map = gim.function2(result_mod, gleam_result.map)
  let list_try_map = gim.function2(list_mod, list.try_map)

  let ts_system = gim.function0(ts_mod, timestamp.system_time)
  let ts_to_unix_ns =
    gim.function1(ts_mod, timestamp.to_unix_seconds_and_nanoseconds)

  let run_write = gim.function3(exec_mod, cake_sql_exec.run_write_query)
  let run_read = gim.function3(exec_mod, cake_sql_exec.run_read_query)

  let conn_t = gtypes.custom_type(Some("sqlight"), "Connection", [])
  let err_t = gtypes.custom_type(Some("sqlight"), "Error", [])
  let row_t = gtypes.custom_type(None, row_name, [])
  let upsert_t = gtypes.custom_type(None, ctx.for_upsert_type_name, [])
  let ret_one = gtypes.result(row_t, err_t)
  let ret_many = gtypes.result(gtypes.list(row_t), err_t)

  let insert_col_strings =
    list.append(list.map(ctx.fields, fn(p) { p.0 }), [
      "created_at",
      "updated_at",
      "deleted_at",
    ])
  let select_col_strings = upsert_select_column_names(ctx)
  let insert_cols_list = gex.list(list.map(insert_col_strings, gex.string))
  let select_cols_list = gex.list(list.map(select_col_strings, gex.string))
  let identity_cols_list = gex.list(list.map(ctx.identity_labels, gex.string))

  let conflict_inner =
    list.fold(
      list.filter(ctx.fields, fn(p) { !list.contains(ctx.identity_labels, p.0) }),
      gex.call0(cu_new),
      fn(acc, pair) {
        gex.call2(
          cu_set,
          acc,
          gex.call2(
            cu_set_expr,
            gex.string(pair.0),
            gex.string("excluded." <> pair.0),
          ),
        )
      },
    )
  let conflict_upd_expr =
    gex.call2(
      cu_set,
      gex.call2(
        cu_set,
        conflict_inner,
        gex.call2(
          cu_set_expr,
          gex.string("updated_at"),
          gex.string("excluded.updated_at"),
        ),
      ),
      gex.call2(cu_set_expr, gex.string("deleted_at"), gex.string("NULL")),
    )

  let trivial_where =
    gex.call2(w_eq, gex.call1(w_int, gex.int(1)), gex.call1(w_int, gex.int(1)))

  let field_patterns =
    list.map(ctx.fields, fn(pair) { gpat.variable(pair.0) |> gpat.to_dynamic })

  let field_binding_at = fn(
    fields: List(#(String, glance.Type)),
    detail_exprs: List(gex.Expression(gtypes.Dynamic)),
    label: String,
  ) -> gex.Expression(gtypes.Dynamic) {
    let indexed = list.index_map(fields, fn(p, i) { #(i, p.0) })
    let assert Ok(#(idx, _)) = list.find(indexed, fn(ix) { ix.1 == label })
    binding_at_index(detail_exprs, idx)
  }

  let insert_value_dyn = fn(
    label: String,
    typ: glance.Type,
    expr: gex.Expression(gtypes.Dynamic),
  ) -> gex.Expression(gtypes.Dynamic) {
    let is_id = list.contains(ctx.identity_labels, label)
    let r = sql_types.rendered_type(typ)
    case is_id {
      True ->
        case r {
          "String" -> gex.call1(ci_string, gex.coerce_dynamic_unsafe(expr))
          "Bool" -> gex.call1(ci_bool, gex.coerce_dynamic_unsafe(expr))
          "Int" -> gex.call1(ci_int, gex.coerce_dynamic_unsafe(expr))
          "Float" -> gex.call1(ci_float, gex.coerce_dynamic_unsafe(expr))
          "Option(String)" ->
            gex.call1(ci_string, gex.coerce_dynamic_unsafe(expr))
          "Option(Int)" -> gex.call1(ci_int, gex.coerce_dynamic_unsafe(expr))
          "Option(Bool)" -> gex.call1(ci_bool, gex.coerce_dynamic_unsafe(expr))
          "Option(Float)" ->
            gex.call1(ci_float, gex.coerce_dynamic_unsafe(expr))
          _ -> gex.call1(ci_string, gex.coerce_dynamic_unsafe(expr))
        }
        |> gex.to_dynamic
      False ->
        case r {
          "Int" ->
            gex.call1(ci_int, gex.coerce_dynamic_unsafe(expr)) |> gex.to_dynamic
          "Float" ->
            gex.call1(ci_float, gex.coerce_dynamic_unsafe(expr))
            |> gex.to_dynamic
          "Bool" ->
            gex.call1(ci_bool, gex.coerce_dynamic_unsafe(expr))
            |> gex.to_dynamic
          "String" ->
            gex.call1(ci_string, gex.coerce_dynamic_unsafe(expr))
            |> gex.to_dynamic
          "Option(Int)" ->
            gcase.new(expr)
            |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
              gex.call1(ci_int, v) |> gex.to_dynamic
            })
            |> gcase.with_pattern(gpat.option_none(), fn(_) {
              gex.raw("cake_insert.null()") |> gex.to_dynamic
            })
            |> gcase.build_expression()
            |> gex.to_dynamic
          "Option(Float)" ->
            gcase.new(expr)
            |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
              gex.call1(ci_float, v) |> gex.to_dynamic
            })
            |> gcase.with_pattern(gpat.option_none(), fn(_) {
              gex.raw("cake_insert.null()") |> gex.to_dynamic
            })
            |> gcase.build_expression()
            |> gex.to_dynamic
          "Option(Bool)" ->
            gcase.new(expr)
            |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
              gex.call1(ci_bool, v) |> gex.to_dynamic
            })
            |> gcase.with_pattern(gpat.option_none(), fn(_) {
              gex.raw("cake_insert.null()") |> gex.to_dynamic
            })
            |> gcase.build_expression()
            |> gex.to_dynamic
          "Option(String)" ->
            gcase.new(expr)
            |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
              gex.call1(ci_string, v) |> gex.to_dynamic
            })
            |> gcase.with_pattern(gpat.option_none(), fn(_) {
              gex.raw("cake_insert.null()") |> gex.to_dynamic
            })
            |> gcase.build_expression()
            |> gex.to_dynamic
          _ ->
            gcase.new(expr)
            |> gcase.with_pattern(gpat.option_some(gpat.variable("v")), fn(v) {
              gex.call1(ci_string, v) |> gex.to_dynamic
            })
            |> gcase.with_pattern(gpat.option_none(), fn(_) {
              gex.raw("cake_insert.null()") |> gex.to_dynamic
            })
            |> gcase.build_expression()
            |> gex.to_dynamic
        }
    }
  }

  let insert_row_values_dynamic = fn(
    detail_exprs: List(gex.Expression(gtypes.Dynamic)),
    stamp_sec: gex.Expression(Int),
  ) {
    let field_vals =
      list.map(ctx.fields, fn(pair) {
        let #(label, typ) = pair
        let ex = field_binding_at(ctx.fields, detail_exprs, label)
        insert_value_dyn(label, typ, ex)
      })
    let tail = [
      gex.call1(ci_int, stamp_sec) |> gex.to_dynamic,
      gex.call1(ci_int, stamp_sec) |> gex.to_dynamic,
      gex.raw("cake_insert.null()") |> gex.to_dynamic,
    ]
    gex.list(list.append(field_vals, tail))
  }

  let identity_where_expressions = fn(
    detail_exprs: List(gex.Expression(gtypes.Dynamic)),
  ) -> List(gex.Expression(where.Where)) {
    list.map(ctx.identity_labels, fn(label) {
      let assert Ok(#(_, typ)) = list.find(ctx.fields, fn(p) { p.0 == label })
      let ex = field_binding_at(ctx.fields, detail_exprs, label)
      case sql_types.rendered_type(typ) {
        "String" ->
          gex.call2(
            w_eq,
            gex.call1(w_col, gex.string(label)),
            gex.call1(w_string, gex.coerce_dynamic_unsafe(ex)),
          )
        "Bool" ->
          gex.call2(
            w_is_bool,
            gex.call1(w_col, gex.string(label)),
            gex.coerce_dynamic_unsafe(ex),
          )
        "Int" ->
          gex.call2(
            w_eq,
            gex.call1(w_col, gex.string(label)),
            gex.call1(w_int, gex.coerce_dynamic_unsafe(ex)),
          )
        "Float" ->
          gex.call2(
            w_eq,
            gex.call1(w_col, gex.string(label)),
            gex.call1(w_float, gex.coerce_dynamic_unsafe(ex)),
          )
        "Option(String)" ->
          gex.call2(
            w_eq,
            gex.call1(w_col, gex.string(label)),
            gex.call1(w_string, gex.coerce_dynamic_unsafe(ex)),
          )
        "Option(Int)" ->
          gex.call2(
            w_eq,
            gex.call1(w_col, gex.string(label)),
            gex.call1(w_int, gex.coerce_dynamic_unsafe(ex)),
          )
        "Option(Bool)" ->
          gex.call2(
            w_is_bool,
            gex.call1(w_col, gex.string(label)),
            gex.coerce_dynamic_unsafe(ex),
          )
        "Option(Float)" ->
          gex.call2(
            w_eq,
            gex.call1(w_col, gex.string(label)),
            gex.call1(w_float, gex.coerce_dynamic_unsafe(ex)),
          )
        _ ->
          gex.call2(
            w_eq,
            gex.call1(w_col, gex.string(label)),
            gex.call1(w_string, gex.coerce_dynamic_unsafe(ex)),
          )
      }
    })
  }

  let upsert_one_fn =
    gfun.new2(
      gparam.new("conn", conn_t),
      gparam.new(singular, upsert_t),
      ret_one,
      fn(conn, sing) {
        gblock.with_matching_let_declaration(
          gpat.tuple2(gpat.variable("stamp_sec"), gpat.discard()),
          gex.call1(ts_to_unix_ns, gex.call0(ts_system)),
          False,
          fn(stamp_pair) {
            let stamp_sec = stamp_pair.0
            gcase.new(sing)
            |> gcase.with_pattern(
              gpat.foreign_variant(variant_name, field_patterns),
              fn(detail_exprs) {
                let row_dyn = insert_row_values_dynamic(detail_exprs, stamp_sec)
                let row_expr =
                  gex.call1(ci_row, gex.coerce_dynamic_unsafe(row_dyn))
                let ins_expr =
                  gex.call1(
                    ci_to_query,
                    gex.call4(
                      ci_on_conflict,
                      gex.call2(
                        ci_source_values,
                        gex.call2(
                          ci_columns,
                          gex.call2(
                            ci_table,
                            gex.call0(ci_new),
                            gex.string(table),
                          ),
                          insert_cols_list,
                        ),
                        gex.list([row_expr]),
                      ),
                      identity_cols_list,
                      trivial_where,
                      conflict_upd_expr,
                    ),
                  )
                let decode_nil = gex.call1(decode_success, gex.nil())
                let try_write = gex.call3(run_write, ins_expr, decode_nil, conn)
                let id_wheres = identity_where_expressions(detail_exprs)
                let deleted_null =
                  gex.call1(
                    w_is_null,
                    gex.call1(w_col, gex.string("deleted_at")),
                  )
                let sel0 =
                  gex.call2(
                    s_cols,
                    gex.call2(s_from, gex.call0(s_new), gex.string(table)),
                    select_cols_list,
                  )
                let wh =
                  gex.call1(
                    w_and,
                    gex.list(list.append(id_wheres, [deleted_null])),
                  )
                let read_q = gex.call1(s_to_q, gex.call2(s_where, sel0, wh))
                let decoder_call = gex.call0(gex.raw(decoder_fn))
                let read_call = gex.call3(run_read, read_q, decoder_call, conn)
                let assert_row = gex.raw("fn(rows) { let assert [r] = rows r }")
                let mapped = gex.call2(result_map, read_call, assert_row)
                gblock.with_use1(
                  gblock.use_function1(result_try, try_write),
                  "_",
                  fn(_) { mapped },
                )
              },
            )
            |> gcase.build_expression()
          },
        )
      },
    )

  let upsert_many_fn =
    gfun.new2(
      gparam.new("conn", conn_t),
      gparam.new("rows", gtypes.list(upsert_t)),
      ret_many,
      fn(conn, rows) {
        gex.call2(
          list_try_map,
          rows,
          gfun.anonymous(
            gfun.new1(gparam.new("c", upsert_t), ret_one, fn(c) {
              gex.call2(
                gex.raw("upsert_one"),
                conn |> gex.coerce_dynamic_unsafe,
                c |> gex.coerce_dynamic_unsafe,
              )
              |> gex.coerce_dynamic_unsafe
            }),
          ),
        )
      },
    )

  gmod.with_import(ci_mod, fn(_) {
    use _ <- gmod.with_import(cu_mod)
    use _ <- gmod.with_import(sel_mod)
    use _ <- gmod.with_import(where_mod)
    use _ <- gmod.with_import(decode_mod)
    use _ <- gmod.with_import(list_mod)
    use _ <- gmod.with_import(option_mod)
    use _ <- gmod.with_import(result_mod)
    use _ <- gmod.with_import(ts_mod)
    use _ <- gmod.with_import(sqlight_mod)
    use _ <- gmod.with_import(resource_mod)
    use _ <- gmod.with_import(structure_mod)
    use _ <- gmod.with_import(exec_mod)
    use _ <- gmod.with_function(
      gleamgen_emit.pub_def("upsert_one"),
      upsert_one_fn,
    )
    gmod.with_function(
      gleamgen_emit.pub_def("upsert_many"),
      upsert_many_fn,
      fn(_) { gmod.eof() },
    )
  })
}

fn binding_at_index(
  xs: List(gex.Expression(gtypes.Dynamic)),
  i: Int,
) -> gex.Expression(gtypes.Dynamic) {
  case i, xs {
    0, [x, ..] -> x
    _, [_, ..rest] -> binding_at_index(rest, i - 1)
    _, [] -> panic as "crud_upsert field index"
  }
}

fn upsert_select_column_names(ctx: SchemaContext) -> List(String) {
  let rest = list.map(ctx.fields, fn(pair) { pair.0 })
  ["id", "created_at", "updated_at", "deleted_at", ..rest]
}
