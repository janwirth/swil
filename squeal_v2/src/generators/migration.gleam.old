import glance
import gleam/list
import gleam/option.{Some}
import gleam/result as gleam_result
import gleam/string

import generators/gleamgen_emit
import generators/schema_context
import generators/sql_types

import gleamgen/expression as gex
import gleamgen/expression/block as gblock
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/parameter as gparam
import gleamgen/types as gtypes

import generators/help/migrate as migration_help
import sqlight

pub fn generate(module: String) -> String {
  let assert Ok(ctx) = schema_context.migration_context(module)
  generate_migration(ctx, ctx.table)
}

fn identity_exec_ddl(module_name: String, labels: List(String)) -> String {
  case labels {
    [] -> ""
    [one] -> {
      let idx = module_name <> "_identity_" <> one <> "_idx"
      "create unique index if not exists "
      <> idx
      <> " on "
      <> module_name
      <> " ("
      <> one
      <> ");"
    }
    many -> {
      let cols = string.join(many, ", ")
      let idx = module_name <> "_identity_idx"
      "create unique index if not exists "
      <> idx
      <> " on "
      <> module_name
      <> " ("
      <> cols
      <> ");"
    }
  }
}

fn generate_migration(
  ctx: schema_context.MigrationContext,
  module_name: String,
) -> String {
  let has_tail_after_columns = case ctx.identity_labels {
    [] -> False
    _ -> True
  }
  let migration_help_mod =
    gim.new_with_alias(["help", "migrate"], "migration_help")
  let result_mod = gim.new(["gleam", "result"])
  let sqlight_mod = gim.new(["sqlight"])

  let ensure_base_table_fn =
    gim.function2(migration_help_mod, migration_help.ensure_base_table)
  let ensure_column_fn =
    gim.function4(migration_help_mod, migration_help.ensure_column)
  let sqlight_exec_fn = gim.function2(sqlight_mod, sqlight.exec)
  let result_try = gim.function2(result_mod, gleam_result.try)

  let conn_t = gtypes.custom_type(Some("sqlight"), "Connection", [])
  let err_t = gtypes.custom_type(Some("sqlight"), "Error", [])
  let ret_t = gtypes.result(gtypes.nil, err_t)

  let migrate_fn =
    gfun.new1(gparam.new("conn", conn_t), ret_t, fn(conn) {
      let base_call =
        gex.call2(ensure_base_table_fn, conn, gex.string(module_name))
      let identity_expr = case ctx.identity_labels {
        [] -> gex.ok(gex.nil())
        labels -> {
          let ddl = identity_exec_ddl(module_name, labels)
          gex.call2(sqlight_exec_fn, gex.string(ddl), conn)
        }
      }
      case ctx.columns {
        [] ->
          case has_tail_after_columns {
            True ->
              gblock.with_use1(
                gblock.use_function1(result_try, base_call),
                "_",
                fn(_) { identity_expr },
              )
            False ->
              gblock.with_use1(
                gblock.use_function1(result_try, base_call),
                "_",
                fn(_) { gex.ok(gex.nil()) },
              )
          }
        cols ->
          gblock.with_use1(
            gblock.use_function1(result_try, base_call),
            "_",
            fn(_) {
              columns_suffix(
                cols,
                0,
                module_name,
                has_tail_after_columns,
                identity_expr,
                conn,
                ensure_column_fn,
                result_try,
              )
            },
          )
      }
    })

  gleamgen_emit.render_module(
    gmod.with_import(migration_help_mod, fn(_) {
      use _ <- gmod.with_import(result_mod)
      use _ <- gmod.with_import(sqlight_mod)
      gmod.with_function(
        gleamgen_emit.pub_def("migrate_idempotent"),
        migrate_fn,
        fn(_) { gmod.eof() },
      )
    }),
  )
}

fn columns_suffix(
  cols: List(#(String, glance.Type)),
  i: Int,
  table: String,
  has_identity_tail: Bool,
  identity_expr,
  conn,
  ensure_column_fn,
  result_try,
) {
  let n = list.length(cols)
  let assert Ok(#(name, typ)) = column_pair_at(cols, i)
  let is_last = i == n - 1
  let alter_sql =
    "alter table "
    <> table
    <> " add column "
    <> name
    <> " "
    <> sql_types.sql_type(typ)
    <> ";"
  let call =
    gex.call4(
      ensure_column_fn,
      conn,
      gex.string(table),
      gex.string(name),
      gex.string(alter_sql),
    )
  case is_last && !has_identity_tail {
    True -> call
    False -> {
      let inner = case is_last {
        True -> identity_expr
        False ->
          columns_suffix(
            cols,
            i + 1,
            table,
            has_identity_tail,
            identity_expr,
            conn,
            ensure_column_fn,
            result_try,
          )
      }
      gblock.with_use1(gblock.use_function1(result_try, call), "_", fn(_) {
        inner
      })
    }
  }
}

fn column_pair_at(
  cols: List(#(String, glance.Type)),
  i: Int,
) -> Result(#(String, glance.Type), Nil) {
  case list.drop(cols, i) {
    [pair, ..] -> Ok(pair)
    [] -> Error(Nil)
  }
}
