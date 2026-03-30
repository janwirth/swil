import generators/sql_types
import glance
import gleam/int
import gleam/list
import gleam/string
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition, type SchemaDefinition,
}
import sql/sqlite_ident

/// Builds the SQL script emitted by the simple DDL migration path: drop stray
/// tables, then `CREATE TABLE` / unique index per entity for the target schema.
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

/// SQLite table name for an entity: lowercased Gleam type name (e.g. `Fruit` → `fruit`).
pub fn entity_table_name(entity_type: String) -> String {
  string.lowercase(entity_type)
}

/// Quote a column or table name for SQLite DDL/DML.
pub fn quote_ident(label: String) -> String {
  sqlite_ident.quote(label)
}

/// True when a field’s Gleam type is `List(_)`, so it is stored outside the main row / DDL.
pub fn type_is_list(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "List", _, _) -> True
    _ -> False
  }
}

/// Maps a field type to SQLite DDL spellings; normalizes `int` to `integer` so
/// `PRAGMA table_info` affinity checks stay consistent with introspection.
fn ddl_sql_type(type_: glance.Type) -> String {
  case sql_types.sql_type(type_) {
    "int" -> "integer"
    other -> other
  }
}

/// `CREATE TABLE IF NOT EXISTS` plus the canonical identity unique index for one entity.
fn entity_ddl(schema: SchemaDefinition, entity: EntityDefinition) -> String {
  let assert Ok(identity_type) =
    list.find(schema.identities, fn(i) {
      i.type_name == entity.identity_type_name
    })
  let assert [variant, ..] = identity_type.variants
  let table = entity_table_name(entity.type_name)
  let qtable = quote_ident(table)
  let data_fields =
    list.filter(entity.fields, fn(f) {
      f.label != "identities"
      && f.label != "relationships"
      && !type_is_list(f.type_)
    })
  let column_lines =
    list.map(data_fields, fn(f) {
      quote_ident(f.label) <> " " <> ddl_sql_type(f.type_) <> " not null"
    })
  let all_columns =
    list.flatten([
      [quote_ident("id") <> " integer primary key autoincrement not null"],
      column_lines,
      [
        quote_ident("created_at") <> " integer not null",
        quote_ident("updated_at") <> " integer not null",
        quote_ident("deleted_at") <> " integer",
      ],
    ])
  let create_table =
    "create table if not exists "
    <> qtable
    <> " (\n  "
    <> string.join(all_columns, ",\n  ")
    <> "\n);"
  let index_suffix =
    list.map(variant.fields, fn(f) { f.label })
    |> string.join("_")
  let index_name = table <> "_by_" <> index_suffix
  let create_index =
    build_create_unique_index_sql(
      table:,
      index_name:,
      index_column_labels: list.map(variant.fields, fn(f) { f.label }),
      if_not_exists: True,
    )
  create_table <> "\n" <> create_index
}

/// Uppercase SQLite affinity labels used in expected `PRAGMA table_info` TSV fixtures.
pub fn pragma_affinity_upper(type_: glance.Type) -> String {
  case ddl_sql_type(type_) {
    "integer" -> "INTEGER"
    "text" -> "TEXT"
    "real" -> "REAL"
    _ -> "TEXT"
  }
}

/// `CREATE TABLE name (...)` for shape-reconcile blueprints (no `IF NOT EXISTS`).
/// [extra_before_deleted] — nullable FK lines (e.g. `owner_human_id integer`) inserted
/// after `updated_at` and before `deleted_at`.
pub fn build_create_table_sql(
  table: String,
  data_fields: List(FieldDefinition),
  extra_before_deleted: List(String),
) -> String {
  let col_lines =
    list.map(data_fields, fn(f) {
      quote_ident(f.label) <> " " <> ddl_sql_type(f.type_) <> " not null"
    })
  let all_lines =
    list.flatten([
      [quote_ident("id") <> " integer primary key autoincrement not null"],
      col_lines,
      [
        quote_ident("created_at") <> " integer not null",
        quote_ident("updated_at") <> " integer not null",
      ],
      extra_before_deleted,
      [quote_ident("deleted_at") <> " integer"],
    ])
  "create table "
  <> quote_ident(table)
  <> " (\n  "
  <> string.join(all_lines, ",\n  ")
  <> "\n);"
}

/// Expected `PRAGMA table_info` TSV body (header + rows) for pragma-based migration tests.
pub fn build_expected_table_info(
  rows: List(#(String, String, Int, Int)),
) -> String {
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

/// Resolves a column label to its `cid` index in the full table column order.
pub fn label_to_cid(full: List(String), label: String) -> Int {
  let assert Ok(#(i, _)) =
    full
    |> list.index_map(fn(name, idx) { #(idx, name) })
    |> list.find(fn(p) { p.1 == label })
  i
}

/// Expected `pragma index_list` TSV snippet for the identity index row (fixture constant).
pub fn build_expected_index_list_row(index_name: String) -> String {
  string.concat([
    "seq\tname\tunique\torigin\tpartial\n0\t",
    index_name,
    "\t1\tc\t0",
  ])
}

/// Expected `PRAGMA index_info` TSV for the identity index column mapping.
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

/// `CREATE UNIQUE INDEX` for the identity index — with or without `IF NOT EXISTS` (DDL bootstrap vs reconcile).
pub fn build_create_unique_index_sql(
  table table: String,
  index_name index_name: String,
  index_column_labels index_column_labels: List(String),
  if_not_exists if_not_exists: Bool,
) -> String {
  let cols =
    index_column_labels
    |> list.map(quote_ident)
    |> string.join(", ")
  case if_not_exists {
    True -> "create unique index if not exists "
    False -> "create unique index "
  }
  <> index_name
  <> " on "
  <> quote_ident(table)
  <> "("
  <> cols
  <> ");"
}
