import generators/pragma_migration_data
import generators/pragma_migration_emit
import generators/sql_types
import glance
import gleam/int
import gleam/list
import gleam/string
import schema_definition.{
  type EntityDefinition, type FieldDefinition, type SchemaDefinition,
}

/// Applies [schema] to the database: drops tables from **other** versions first
/// (`drop_tables_not_in_schema` — e.g. `["animal"]` when migrating to fruit-only),
/// then creates each entity table and its identity indexes. Idempotent when re-run.
pub fn generate_migration(
  schema: SchemaDefinition,
  drop_tables_not_in_schema: List(String),
) -> String {
  let drops =
    list.map(drop_tables_not_in_schema, fn(t) {
      "drop table if exists " <> t <> ";"
    })
    |> string.join("\n")
  let creates =
    schema.entities
    |> list.map(fn(entity) { entity_ddl(schema, entity) })
    |> string.join("\n")
  case drops == "" {
    True -> creates
    False -> drops <> "\n" <> creates
  }
}

pub fn entity_table_name(entity_type: String) -> String {
  string.lowercase(entity_type)
}

pub fn type_is_list(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "List", _, _) -> True
    _ -> False
  }
}

/// Affinity spelling so `pragma table_info` matches INTEGER (not INT).
fn ddl_sql_type(type_: glance.Type) -> String {
  case sql_types.sql_type(type_) {
    "int" -> "integer"
    other -> other
  }
}

fn entity_ddl(schema: SchemaDefinition, entity: EntityDefinition) -> String {
  let assert Ok(identity_type) =
    list.find(schema.identities, fn(i) {
      i.type_name == entity.identity_type_name
    })
  let assert [variant, ..] = identity_type.variants
  let table = entity_table_name(entity.type_name)
  let data_fields =
    list.filter(entity.fields, fn(f) {
      f.label != "identities"
      && f.label != "relationships"
      && !type_is_list(f.type_)
    })
  let column_lines =
    list.map(data_fields, fn(f) {
      f.label <> " " <> ddl_sql_type(f.type_) <> " not null"
    })
  let all_columns =
    list.flatten([
      ["id integer primary key autoincrement not null"],
      column_lines,
      [
        "created_at integer not null",
        "updated_at integer not null",
        "deleted_at integer",
      ],
    ])
  let create_table =
    "create table if not exists "
    <> table
    <> " (\n  "
    <> string.join(all_columns, ",\n  ")
    <> "\n);"
  let cols =
    list.map(variant.fields, fn(f) { f.label })
    |> string.join(", ")
  let index_suffix =
    list.map(variant.fields, fn(f) { f.label })
    |> string.join("_")
  let index_name = table <> "_by_" <> index_suffix
  let create_index =
    "create unique index if not exists "
    <> index_name
    <> " on "
    <> table
    <> "("
    <> cols
    <> ");"
  create_table <> "\n" <> create_index
}

pub fn pragma_affinity_upper(type_: glance.Type) -> String {
  case ddl_sql_type(type_) {
    "integer" -> "INTEGER"
    "text" -> "TEXT"
    "real" -> "REAL"
    _ -> "TEXT"
  }
}

pub fn build_create_table_sql(
  table: String,
  data_fields: List(FieldDefinition),
) -> String {
  let col_lines =
    list.map(data_fields, fn(f) {
      f.label <> " " <> ddl_sql_type(f.type_) <> " not null"
    })
  let all_lines =
    list.flatten([
      ["id integer primary key autoincrement not null"],
      col_lines,
      [
        "created_at integer not null",
        "updated_at integer not null",
        "deleted_at integer",
      ],
    ])
  "create table "
  <> table
  <> " (\n  "
  <> string.join(all_lines, ",\n  ")
  <> "\n);"
}

pub fn build_expected_table_info(rows: List(#(String, String, Int, Int))) -> String {
  let body =
    rows
    |> list.index_map(fn(row, cid) {
      let #(name, typ, notnull, pk) = row
      int.to_string(cid)
      <> "\t"
      <> name
      <> "\t"
      <> typ
      <> "\t"
      <> int.to_string(notnull)
      <> "\tNULL\t"
      <> int.to_string(pk)
    })
    |> string.join("\n")
  "cid\tname\ttype\tnotnull\tdflt_value\tpk\n" <> body
}

pub fn label_to_cid(full: List(String), label: String) -> Int {
  let assert Ok(#(i, _)) =
    full
    |> list.index_map(fn(name, idx) { #(idx, name) })
    |> list.find(fn(p) { p.1 == label })
  i
}

pub fn build_expected_index_info(
  id_fields: List(FieldDefinition),
  full_col_names: List(String),
) -> String {
  let body =
    id_fields
    |> list.index_map(fn(f, seq) {
      let cid = label_to_cid(full_col_names, f.label)
      int.to_string(seq) <> "\t" <> int.to_string(cid) <> "\t" <> f.label
    })
    |> string.join("\n")
  "seqno\tcid\tname\n" <> body
}

fn pragma_gleam_quote(s: String) -> String {
  "\"" <> s <> "\""
}

fn build_pragma_migration_data(
  schema: SchemaDefinition,
  module_tag: String,
) -> pragma_migration_data.PragmaMigrationData {
  let assert [entity] = schema.entities
  let table = entity_table_name(entity.type_name)
  let col_type = string.append(entity.type_name, "Col")
  let assert Ok(identity_type) =
    list.find(schema.identities, fn(i) {
      i.type_name == entity.identity_type_name
    })
  let assert [variant, ..] = identity_type.variants
  let data_fields =
    list.filter(entity.fields, fn(f) {
      f.label != "identities"
      && f.label != "relationships"
      && !type_is_list(f.type_)
    })
  let index_suffix =
    list.map(variant.fields, fn(f) { f.label })
    |> string.join("_")
  let index_name = table <> "_by_" <> index_suffix
  let index_cols =
    list.map(variant.fields, fn(f) { f.label }) |> string.join(", ")
  let full_col_names =
    list.flatten([
      ["id"],
      list.map(data_fields, fn(f) { f.label }),
      ["created_at", "updated_at", "deleted_at"],
    ])
  let wanted_rows =
    list.flatten([
      [#("id", "INTEGER", 1, 1)],
      list.map(data_fields, fn(f) {
        #(f.label, pragma_affinity_upper(f.type_), 1, 0)
      }),
      [
        #("created_at", "INTEGER", 1, 0),
        #("updated_at", "INTEGER", 1, 0),
        #("deleted_at", "INTEGER", 0, 0),
      ],
    ])
  let create_table_sql = build_create_table_sql(table, data_fields)
  let create_index_sql =
    "create unique index "
    <> index_name
    <> " on "
    <> table
    <> "("
    <> index_cols
    <> ");"
  let expected_table_info = build_expected_table_info(wanted_rows)
  let expected_index_list =
    "seq\tname\tunique\torigin\tpartial\n0\t" <> index_name <> "\t1\tc\t0"
  let expected_index_info =
    build_expected_index_info(variant.fields, full_col_names)
  let panic_lit =
    pragma_gleam_quote(module_tag <> ": no column fix applies")
  let none_panic_line =
    "            None -> panic as " <> panic_lit
  let apply_one_none_panic = case string.length(none_panic_line) > 79 {
    True ->
      string.join(
        [
          "            None ->",
          "              panic as " <> panic_lit,
        ],
        "\n",
      )
    False -> none_panic_line
  }
  let conn_t =
    "(conn, " <> pragma_gleam_quote(table) <> ")"
  let table_info_try =
    "      use rows <- result.try(sqlite_pragma_assert.table_info_rows"
    <> conn_t
    <> "))"
  let reconcile_table_info_rows_stmt = case string.length(table_info_try) > 81 {
    True ->
      string.join(
        [
          "      use rows <- result.try(sqlite_pragma_assert.table_info_rows(",
          "        conn,",
          "        " <> pragma_gleam_quote(table) <> ",",
          "      ))",
        ],
        "\n",
      )
    False -> table_info_try
  }
  let panic_no_conv =
    pragma_gleam_quote(module_tag <> ": column reconcile did not converge")

  pragma_migration_data.PragmaMigrationData(
    table:,
    col_type:,
    index_suffix:,
    index_name:,
    create_table_sql:,
    create_index_sql:,
    expected_table_info:,
    expected_index_list:,
    expected_index_info:,
    wanted_rows:,
    apply_one_none_panic:,
    reconcile_table_info_rows_stmt:,
    panic_no_conv:,
  )
}

/// Gleam source for a single-entity pragma reconcile blueprint like
/// `example_migration_fruit` / `example_migration_animal`. [module_tag] appears in
/// panic strings (e.g. `example_migration_fruit`).
pub fn generate_pragma_migration_module(
  schema: SchemaDefinition,
  module_tag: String,
) -> String {
  pragma_migration_emit.emit(build_pragma_migration_data(schema, module_tag))
}
