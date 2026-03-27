import generators/migration/migration_sql
import generators/migration/pragma_migration_data
import generators/migration/pragma_migration_emit
import generators/migration/pragma_migration_panic
import glance
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/expression/statement as gstmt
import gleamgen/render as grender
import schema_definition/schema_definition.{
  type EntityDefinition,
  type FieldDefinition,
  type SchemaDefinition,
}

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
  migration_sql.build_create_table_sql(table, data_fields, [])
}

fn unwrap_option_type(t: glance.Type) -> glance.Type {
  case t {
    glance.NamedType(_, "Option", _, [inner]) -> inner
    
    _ -> t
  }
}

fn named_type_name(t: glance.Type) -> Option(String) {
  case t {
    glance.NamedType(_, n, None, []) | glance.NamedType(_, n, Some(_), []) ->
      Some(n)
    _ -> None
  }
}

fn relationship_container_field_defs(
  schema: SchemaDefinition,
  entity: EntityDefinition,
) -> List(FieldDefinition) {
  case list.find(entity.fields, fn(f) { f.label == "relationships" }) {
    Error(Nil) -> []
    Ok(f) -> {
      let inner = unwrap_option_type(f.type_)
      case named_type_name(inner) {
        None -> []
        Some(container_name) ->
          case
            list.find(schema.relationship_containers, fn(c) {
              c.type_name == container_name
            })
          {
            Error(Nil) -> []
            Ok(container) -> {
              let assert [vw, ..] = container.variants
              vw.fields
            }
          }
      }
    }
  }
}

fn belongs_to_fk_column_names(rel_fields: List(FieldDefinition)) -> List(String) {
  list.filter_map(rel_fields, fn(field) {
    let t = unwrap_option_type(field.type_)
    case t {
      glance.NamedType(_, "BelongsTo", _, [
        glance.NamedType(_, target, _, _),
        _,
      ]) -> Ok(field.label <> "_" <> string.lowercase(target) <> "_id")
      _ -> Error(Nil)
    }
  })
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

// --- Pragma migration module generation ---

/// Gleam `use rows <- result.try(table_info_rows(...))` as a statement AST; rendered by gleamgen.
fn render_reconcile_table_info_rows_use(table: String) -> String {
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
  let rendered =
    gexpr.render_statement(stmt, grender.default_context())
    |> grender.to_string()
    |> string.trim_end
  rendered
  |> string.split("\n")
  |> list.map(fn(line) { string.append("      ", line) })
  |> string.join("\n")
}

fn panic_as_literal(message: String) -> String {
  string.concat(["\"", message, "\""])
}

/// Fills `PragmaMigrationData` for one entity (fixtures and panic snippets).
pub fn build_pragma_migration_data_for_entity(
  schema: SchemaDefinition,
  entity: EntityDefinition,
  module_tag: String,
  multi_entity: Bool,
) -> pragma_migration_data.PragmaMigrationData {
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
  let rel_fields = relationship_container_field_defs(schema, entity)
  let fk_col_names = belongs_to_fk_column_names(rel_fields)
  let fk_sql_lines =
    list.map(fk_col_names, fn(col) {
      migration_sql.quote_ident(col) <> " integer"
    })
  let fk_wanted_rows =
    list.map(fk_col_names, fn(col) { #(col, "INTEGER", 0, 0) })
  let index_suffix =
    list.map(variant.fields, fn(f) { f.label })
    |> string.join("_")
  let index_name = string.append(string.append(table, "_by_"), index_suffix)
  let full_col_names =
    list.flatten([
      ["id"],
      list.map(data_fields, fn(f) { f.label }),
      ["created_at", "updated_at"],
      fk_col_names,
      ["deleted_at"],
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
      ],
      fk_wanted_rows,
      [#("deleted_at", "INTEGER", 0, 0)],
    ])
  let create_table_sql =
    migration_sql.build_create_table_sql(table, data_fields, fk_sql_lines)
  let create_index_sql =
    migration_sql.build_create_unique_index_sql(
      table:,
      index_name:,
      index_column_labels: list.map(variant.fields, fn(f) { f.label }),
      if_not_exists: False,
    )
  let expected_table_info = migration_sql.build_expected_table_info(wanted_rows)
  let expected_index_list =
    migration_sql.build_expected_index_list_row(index_name)
  let expected_index_info =
    migration_sql.build_expected_index_info(variant.fields, full_col_names)
  let panic_no_conv =
    panic_as_literal(
      pragma_migration_panic.column_reconcile_no_convergence_message(module_tag),
    )
  let none_panic_inner =
    panic_as_literal(pragma_migration_panic.no_column_fix_message(module_tag))
  let none_panic_line =
    string.concat(["            None -> panic as ", none_panic_inner])
  let apply_one_none_panic = case string.length(none_panic_line) > 79 {
    True ->
      string.join(
        [
          "            None ->",
          string.concat(["              panic as ", none_panic_inner]),
        ],
        "\n",
      )
    False -> none_panic_line
  }
  let reconcile_table_info_rows_stmt =
    render_reconcile_table_info_rows_use(table)

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
    multi_entity:,
  )
}

/// Full Gleam module text for pragma reconcile migrations: one module per schema,
/// single- or multi-entity.
/// [module_tag] is baked into panic messages so failures name the generating module.
pub fn generate_pragma_migration_module(
  schema: SchemaDefinition,
  module_tag: String,
) -> String {
  let entities =
    list.sort(schema.entities, fn(a, b) { string.compare(a.type_name, b.type_name) })
  let multi_entity = list.length(entities) > 1
  let datas =
    list.map(entities, fn(e) {
      build_pragma_migration_data_for_entity(schema, e, module_tag, multi_entity)
    })
  case multi_entity {
    False -> {
      let assert [d] = datas
      pragma_migration_emit.emit(d)
    }
    True -> pragma_migration_emit.emit_multi(datas)
  }
}
