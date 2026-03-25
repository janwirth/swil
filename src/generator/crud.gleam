import gleam/option.{Some}

import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext}

import gleamgen/expression as gex
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/parameter as gparam
import gleamgen/types as gtypes

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let schema_mod = ctx.schema_module
  let t = ctx.type_name
  let upsert = ctx.for_upsert_type_name
  let fe = ctx.field_enum_name
  let fl = ctx.filterable_name
  let db = ctx.db_type_name
  let table_fn = ctx.table

  let option_mod =
    gim.new_predefined_with_exposing(["gleam", "option"], "type Option")
  let sqlight_mod = gim.new_predefined(["sqlight"])
  let crud_delete_mod =
    gim.new_predefined_with_alias([layer, "crud", "delete"], "crud_delete")
  let crud_filter_mod =
    gim.new_predefined_with_alias([layer, "crud", "filter"], "crud_filter")
  let crud_read_mod =
    gim.new_predefined_with_alias([layer, "crud", "read"], "crud_read")
  let crud_update_mod =
    gim.new_predefined_with_alias([layer, "crud", "update"], "crud_update")
  let crud_upsert_mod =
    gim.new_predefined_with_alias([layer, "crud", "upsert"], "crud_upsert")
  let migrate_mod = gim.new_predefined([layer, "migrate"])
  let resource_mod =
    gim.new_predefined_with_exposing([layer, "resource"], "type " <> upsert)
  let structure_exposing =
    "type "
    <> fe
    <> ", type "
    <> db
    <> ", type "
    <> fl
    <> ", type NumRefOrValue,\n  type StringRefOrValue, "
    <> db
  let structure_mod =
    gim.new_predefined_with_exposing([layer, "structure"], structure_exposing)
  let schema_import_mod =
    gim.new_predefined_with_exposing([schema_mod], "type " <> t)
  let filter_help_mod = gim.new_predefined(["help", "filter"])

  let conn_t = gtypes.custom_type(Some("sqlight"), "Connection", [])

  let filter_arg_fn =
    gfun.new2(
      gparam.new("nullable_filter", gtypes.raw("Option(Filter)")),
      gparam.new("sort", gtypes.raw("Option(filter.SortOrder(" <> fe <> "))")),
      gtypes.raw(
        "filter.FilterArg("
        <> fl
        <> ", NumRefOrValue, StringRefOrValue, "
        <> fe
        <> ")",
      ),
      fn(nullable_filter, sort) {
        gex.call2(
          gim.raw_ident(crud_filter_mod, "filter_arg"),
          nullable_filter,
          sort,
        )
      },
    )

  let cats_fn =
    gfun.new1(gparam.new("conn", conn_t), gtypes.raw(db), fn(_conn) {
      gex.raw(cats_record_source(ctx))
    })

  gleamgen_emit.render_module(
    gmod.with_import(option_mod, fn(_) {
      use _ <- gmod.with_import(sqlight_mod)
      use _ <- gmod.with_import(crud_delete_mod)
      use _ <- gmod.with_import(crud_filter_mod)
      use _ <- gmod.with_import(crud_read_mod)
      use _ <- gmod.with_import(crud_update_mod)
      use _ <- gmod.with_import(crud_upsert_mod)
      use _ <- gmod.with_import(migrate_mod)
      use _ <- gmod.with_import(resource_mod)
      use _ <- gmod.with_import(structure_mod)
      use _ <- gmod.with_import(schema_import_mod)
      use _ <- gmod.with_import(filter_help_mod)
      gmod.with_type_alias(
        gleamgen_emit.pub_def("Filter"),
        gtypes.raw("crud_filter.Filter"),
        fn(_) {
          use _ <- gmod.with_function(
            gleamgen_emit.pub_def("filter_arg"),
            filter_arg_fn,
          )
          gmod.with_function(gleamgen_emit.pub_def(table_fn), cats_fn, fn(_) {
            gmod.eof()
          })
        },
      )
    }),
  )
}

fn cats_record_source(ctx: SchemaContext) -> String {
  let singular = ctx.singular
  let db = ctx.db_type_name
  let t = ctx.type_name
  let upsert = ctx.for_upsert_type_name
  let fl = ctx.filterable_name
  let fe = ctx.field_enum_name
  db
  <> "(\n"
  <> "    migrate: fn() { migrate.migrate_idempotent(conn) },\n"
  <> "    upsert_one: fn("
  <> singular
  <> ": "
  <> upsert
  <> ") { crud_upsert.upsert_one(conn, "
  <> singular
  <> ") },\n"
  <> "    upsert_many: fn(rows: List("
  <> upsert
  <> ")) {\n"
  <> "      crud_upsert.upsert_many(conn, rows)\n"
  <> "    },\n"
  <> "    update_one: fn(id: Int, "
  <> singular
  <> ": "
  <> t
  <> ") { crud_update.update_one(conn, id, "
  <> singular
  <> ") },\n"
  <> "    update_many: fn(rows: List(#(Int, "
  <> t
  <> "))) {\n"
  <> "      crud_update.update_many(conn, rows)\n"
  <> "    },\n"
  <> "    read_one: fn(id: Int) { crud_read.read_one(conn, id) },\n"
  <> "    read_many: fn(\n"
  <> "      arg: filter.FilterArg(\n"
  <> "        "
  <> fl
  <> ",\n"
  <> "        NumRefOrValue,\n"
  <> "        StringRefOrValue,\n"
  <> "        "
  <> fe
  <> ",\n"
  <> "      ),\n"
  <> "    ) {\n"
  <> "      crud_read.read_many(conn, arg)\n"
  <> "    },\n"
  <> "    delete_one: fn(id: Int) { crud_delete.delete_one(conn, id) },\n"
  <> "    delete_many: fn(ids: List(Int)) { crud_delete.delete_many(conn, ids) },\n"
  <> "  )"
}
