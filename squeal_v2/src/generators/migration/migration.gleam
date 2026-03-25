import generators/migration/migration_sql
import generators/migration/pragma_migration_data
import generators/migration/pragma_migration_emit
import glance
import gleam/list
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/expression/statement as gstmt
import gleamgen/render as grender
import schema_definition.{type FieldDefinition, type SchemaDefinition}

// --- Re-exports: SQL helpers live in `migration_sql` for a smaller API surface here. ---

/// Applies [schema] to the database: drops tables from **other** versions first
/// (`drop_tables_not_in_schema` — e.g. `["animal"]` when migrating to fruit-only),
/// then creates each entity table and its identity indexes. Idempotent when re-run.
pub fn generate_migration(
  schema: SchemaDefinition,
  drop_tables_not_in_schema: List(String),
) -> String {
  migration_sql.generate_migration(schema, drop_tables_not_in_schema)
}

/// SQLite table name for an entity: lowercased Gleam type name (e.g. `Fruit` → `fruit`).
pub fn entity_table_name(entity_type: String) -> String {
  migration_sql.entity_table_name(entity_type)
}

/// True when a field’s Gleam type is `List(_)`, so it is stored outside the main row / DDL.
pub fn type_is_list(t: glance.Type) -> Bool {
  migration_sql.type_is_list(t)
}

/// Uppercase SQLite affinity labels used in expected `PRAGMA table_info` TSV fixtures.
pub fn pragma_affinity_upper(t: glance.Type) -> String {
  migration_sql.pragma_affinity_upper(t)
}

/// `CREATE TABLE name (...)` for shape-reconcile blueprints (no `IF NOT EXISTS`).
pub fn build_create_table_sql(
  table: String,
  data_fields: List(FieldDefinition),
) -> String {
  migration_sql.build_create_table_sql(table, data_fields)
}

/// Expected `PRAGMA table_info` TSV (header + rows) for pragma-based migration tests.
pub fn build_expected_table_info(
  rows: List(#(String, String, Int, Int)),
) -> String {
  migration_sql.build_expected_table_info(rows)
}

/// Maps a column label to its `cid` index in the full table column order.
pub fn label_to_cid(full: List(String), label: String) -> Int {
  migration_sql.label_to_cid(full, label)
}

/// Expected `PRAGMA index_info` TSV for the identity index column mapping.
pub fn build_expected_index_info(
  id_fields: List(FieldDefinition),
  full_col_names: List(String),
) -> String {
  migration_sql.build_expected_index_info(id_fields, full_col_names)
}

// --- Pragma migration module generation (Gleam source, not raw SQL). ---

/// Double-quoted string literal for embedding in generated Gleam (panics, table names in code).
fn pragma_gleam_quote(s: String) -> String {
  "\"" <> s <> "\""
}

/// Renders the `use rows <- result.try(sqlite_pragma_assert.table_info_rows(...))` statement
/// via gleamgen; `pragma_migration_emit` splits on newlines and each line is indented for the loop body.
fn reconcile_table_info_rows_stmt_source(table: String) -> String {
  let stmt =
    gstmt.dynamic_use(
      gexpr.raw("result.try"),
      [
        gexpr.call2(
          gexpr.raw("sqlite_pragma_assert.table_info_rows"),
          gexpr.raw("conn"),
          gexpr.string(table),
        )
        |> gexpr.to_dynamic,
      ],
      ["rows"],
    )
  let body =
    gexpr.render_statement(stmt, grender.default_context())
    |> grender.to_string()
    |> string.trim_end
  body
  |> string.split("\n")
  |> list.map(fn(line) { "      " <> line })
  |> string.join("\n")
}

/// Fills `PragmaMigrationData` for a single-entity schema: SQL/TSV fixtures, panic snippets,
/// and the pre-rendered reconcile `use` statement.
fn build_pragma_migration_data(
  schema: SchemaDefinition,
  module_tag: String,
) -> pragma_migration_data.PragmaMigrationData {
  let assert [entity] = schema.entities
  let table = migration_sql.entity_table_name(entity.type_name)
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
      && !migration_sql.type_is_list(f.type_)
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
        #(f.label, migration_sql.pragma_affinity_upper(f.type_), 1, 0)
      }),
      [
        #("created_at", "INTEGER", 1, 0),
        #("updated_at", "INTEGER", 1, 0),
        #("deleted_at", "INTEGER", 0, 0),
      ],
    ])
  let create_table_sql = migration_sql.build_create_table_sql(table, data_fields)
  let create_index_sql =
    migration_sql.build_create_unique_index_sql(
      table:,
      index_name:,
      index_columns_csv: index_cols,
      if_not_exists: False,
    )
  let expected_table_info = migration_sql.build_expected_table_info(wanted_rows)
  let expected_index_list =
    "seq\tname\tunique\torigin\tpartial\n0\t" <> index_name <> "\t1\tc\t0"
  let expected_index_info =
    migration_sql.build_expected_index_info(variant.fields, full_col_names)
  let panic_lit = pragma_gleam_quote(module_tag <> ": no column fix applies")
  let none_panic_line = "            None -> panic as " <> panic_lit
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
  let reconcile_table_info_rows_stmt = reconcile_table_info_rows_stmt_source(table)
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

/// Full Gleam module text for a single-entity pragma reconcile blueprint (e.g. fruit/animal examples).
/// [module_tag] is baked into panic messages so failures name the generating module.
pub fn generate_pragma_migration_module(
  schema: SchemaDefinition,
  module_tag: String,
) -> String {
  pragma_migration_emit.emit(build_pragma_migration_data(schema, module_tag))
}
