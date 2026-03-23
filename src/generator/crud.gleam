import generator/schema_context.{type SchemaContext}

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let schema_mod = ctx.schema_module
  let t = ctx.type_name
  let upsert = ctx.for_upsert_type_name
  let fe = ctx.field_enum_name
  let fl = ctx.filterable_name
  let db = ctx.db_type_name
  let table_fn = ctx.table
  let singular = ctx.singular
  "import gleam/option.{type Option}\n"
  <> "import sqlight\n"
  <> "\n"
  <> "import "
  <> layer
  <> "/crud/delete as crud_delete\n"
  <> "import "
  <> layer
  <> "/crud/filter as crud_filter\n"
  <> "import "
  <> layer
  <> "/crud/read as crud_read\n"
  <> "import "
  <> layer
  <> "/crud/upsert as crud_upsert\n"
  <> "import "
  <> layer
  <> "/crud/update as crud_update\n"
  <> "import "
  <> layer
  <> "/migrate\n"
  <> "import "
  <> layer
  <> "/resource.{type "
  <> upsert
  <> "}\n"
  <> "import "
  <> layer
  <> "/structure.{\n"
  <> "  type "
  <> fe
  <> ",\n"
  <> "  type "
  <> db
  <> ",\n"
  <> "  type "
  <> fl
  <> ",\n"
  <> "  type NumRefOrValue,\n"
  <> "  type StringRefOrValue,\n"
  <> "  "
  <> db
  <> ",\n"
  <> "}\n"
  <> "import help/filter\n"
  <> "import "
  <> schema_mod
  <> ".{type "
  <> t
  <> "}\n"
  <> "\n"
  <> "pub type Filter = crud_filter.Filter\n"
  <> "\n"
  <> "pub fn filter_arg(\n"
  <> "  nullable_filter: Option(Filter),\n"
  <> "  sort: Option(filter.SortOrder("
  <> fe
  <> ")),\n"
  <> ") -> filter.FilterArg("
  <> fl
  <> ", NumRefOrValue, StringRefOrValue, "
  <> fe
  <> ") {\n"
  <> "  crud_filter.filter_arg(nullable_filter, sort)\n"
  <> "}\n"
  <> "\n"
  <> "pub fn "
  <> table_fn
  <> "(conn: sqlight.Connection) -> "
  <> db
  <> " {\n"
  <> "  "
  <> db
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
  <> ")) { crud_upsert.upsert_many(conn, rows) },\n"
  <> "    update_one: fn(id: Int, "
  <> singular
  <> ": "
  <> t
  <> ") { crud_update.update_one(conn, id, "
  <> singular
  <> ") },\n"
  <> "    update_many: fn(rows: List(#(Int, "
  <> t
  <> "))) { crud_update.update_many(conn, rows) },\n"
  <> "    read_one: fn(id: Int) { crud_read.read_one(conn, id) },\n"
  <> "    read_many: fn(arg: filter.FilterArg(\n"
  <> "      "
  <> fl
  <> ",\n"
  <> "      NumRefOrValue,\n"
  <> "      StringRefOrValue,\n"
  <> "      "
  <> fe
  <> ",\n"
  <> "    )) { crud_read.read_many(conn, arg) },\n"
  <> "    delete_one: fn(id: Int) { crud_delete.delete_one(conn, id) },\n"
  <> "    delete_many: fn(ids: List(Int)) { crud_delete.delete_many(conn, ids) },\n"
  <> "  )\n"
  <> "}\n"
}
