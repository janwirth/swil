import generators/gleam_format_generated as gleam_fmt
import generators/migration/migration_sql
import generators/migration/pragma_migration_data
import generators/migration/pragma_migration_emit
import generators/migration/pragma_migration_panic
import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/expression/statement as gstmt
import gleamgen/render as grender
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition, type SchemaDefinition,
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
      glance.NamedType(_, "BelongsTo", _, [first, _])
      | glance.NamedType(_, "dsl.BelongsTo", _, [first, _]) ->
        case belongs_to_target_name(first) {
          Some(target) ->
            Ok(field.label <> "_" <> string.lowercase(target) <> "_id")
          None -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  })
}

fn belongs_to_target_name(t: glance.Type) -> Option(String) {
  case t {
    glance.NamedType(_, target, _, []) -> Some(target)
    glance.NamedType(_, "Option", _, [inner])
    | glance.NamedType(_, "option.Option", _, [inner]) ->
      belongs_to_target_name(inner)
    _ -> None
  }
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
        let notnull = case migration_sql.type_is_option(f.type_) {
          True -> 0
          False -> 1
        }
        #(f.label, migration_sql.pragma_affinity_upper(f.type_), notnull, 0)
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

// =============================================================================
// Junction table (many-to-many via List(BelongsTo(...))) generation
// =============================================================================

type JunctionSpec {
  JunctionSpec(
    root_entity: String,
    target_entity: String,
    edge_fields: List(FieldDefinition),
  )
}

fn find_junction_specs(schema: SchemaDefinition) -> List(JunctionSpec) {
  list.flat_map(schema.relationship_containers, fn(container) {
    let root_entity =
      list.find(schema.entities, fn(e) {
        list.any(e.fields, fn(f) {
          f.label == "relationships"
          && named_type_name(f.type_) == Some(container.type_name)
        })
      })
    case root_entity {
      Error(_) -> []
      Ok(entity) -> {
        let assert [variant, ..] = container.variants
        list.filter_map(variant.fields, fn(field) {
          case field.type_ {
            glance.NamedType(
              _,
              "List",
              _,
              [
                glance.NamedType(
                  _,
                  "BelongsTo",
                  _,
                  [
                    glance.NamedType(_, target_name, _, []),
                    glance.NamedType(_, edge_attribs_name, _, []),
                  ],
                ),
              ],
            ) -> {
              let edge_fields = case
                list.find(schema.relationship_edge_attributes, fn(ea) {
                  ea.type_name == edge_attribs_name
                })
              {
                Ok(ea) -> {
                  let assert [v, ..] = ea.variants
                  v.fields
                }
                Error(_) -> []
              }
              Ok(JunctionSpec(
                root_entity: entity.type_name,
                target_entity: target_name,
                edge_fields: edge_fields,
              ))
            }
            _ -> Error(Nil)
          }
        })
      }
    }
  })
}

/// True when junction `upsert_*` helpers are appended to `*_db/cmd.gleam`.
pub fn schema_has_junction_upserts(schema: SchemaDefinition) -> Bool {
  case find_junction_specs(schema) {
    [] -> False
    [_, ..] -> True
  }
}

fn junction_field_base_sql_type(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Int", _, _) -> "integer"
    glance.NamedType(_, "Bool", _, _) -> "integer"
    glance.NamedType(_, "Float", _, _) -> "real"
    _ -> "text"
  }
}

fn junction_field_sql_type(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Option", _, [inner]) ->
      junction_field_base_sql_type(inner)
    other -> junction_field_base_sql_type(other) <> " not null"
  }
}

fn junction_gleam_base_type(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Int", _, _) -> "Int"
    glance.NamedType(_, "Float", _, _) -> "Float"
    glance.NamedType(_, "Bool", _, _) -> "Bool"
    glance.NamedType(_, "String", _, _) -> "String"
    _ -> "String"
  }
}

fn junction_gleam_type(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Option", _, [inner]) ->
      "option.Option(" <> junction_gleam_base_type(inner) <> ")"
    other -> junction_gleam_base_type(other)
  }
}

fn junction_sqlight_bind(field_name: String, t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "Int", _, _)]) ->
      "case "
      <> field_name
      <> " { option.Some(v) -> sqlight.int(v) option.None -> sqlight.null() }"
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "Float", _, _)]) ->
      "case "
      <> field_name
      <> " { option.Some(v) -> sqlight.float(v) option.None -> sqlight.null() }"
    glance.NamedType(_, "Option", _, _) ->
      "case "
      <> field_name
      <> " { option.Some(v) -> sqlight.text(v) option.None -> sqlight.null() }"
    glance.NamedType(_, "Int", _, _) -> "sqlight.int(" <> field_name <> ")"
    glance.NamedType(_, "Float", _, _) -> "sqlight.float(" <> field_name <> ")"
    _ -> "sqlight.text(" <> field_name <> ")"
  }
}

fn junction_ddl_sql(spec: JunctionSpec) -> String {
  let jt =
    string.lowercase(spec.root_entity)
    <> "_"
    <> string.lowercase(spec.target_entity)
  let root_fk = string.lowercase(spec.root_entity) <> "_id"
  let target_fk = string.lowercase(spec.target_entity) <> "_id"
  let edge_col_lines =
    list.map(spec.edge_fields, fn(f) {
      "  "
      <> migration_sql.quote_ident(f.label)
      <> " "
      <> junction_field_sql_type(f.type_)
    })
  let all_col_lines =
    list.flatten([
      [
        "  " <> migration_sql.quote_ident(root_fk) <> " integer not null",
        "  " <> migration_sql.quote_ident(target_fk) <> " integer not null",
      ],
      edge_col_lines,
      [
        "  unique ("
        <> migration_sql.quote_ident(root_fk)
        <> ", "
        <> migration_sql.quote_ident(target_fk)
        <> ")",
      ],
    ])
  "create table if not exists "
  <> migration_sql.quote_ident(jt)
  <> " (\n"
  <> string.join(all_col_lines, ",\n")
  <> "\n);"
}

fn junction_upsert_sql(spec: JunctionSpec) -> String {
  let jt =
    string.lowercase(spec.root_entity)
    <> "_"
    <> string.lowercase(spec.target_entity)
  let root_fk = string.lowercase(spec.root_entity) <> "_id"
  let target_fk = string.lowercase(spec.target_entity) <> "_id"
  let all_col_names =
    list.flatten([
      [root_fk, target_fk],
      list.map(spec.edge_fields, fn(f) { f.label }),
    ])
  let placeholders = list.map(all_col_names, fn(_) { "?" }) |> string.join(", ")
  let update_cols =
    list.map(spec.edge_fields, fn(f) {
      migration_sql.quote_ident(f.label)
      <> " = excluded."
      <> migration_sql.quote_ident(f.label)
    })
  let update_clause = case update_cols {
    [] ->
      migration_sql.quote_ident(root_fk)
      <> " = excluded."
      <> migration_sql.quote_ident(root_fk)
    _ -> string.join(update_cols, ", ")
  }
  let cols_sql =
    list.map(all_col_names, migration_sql.quote_ident) |> string.join(", ")
  "insert into "
  <> migration_sql.quote_ident(jt)
  <> " ("
  <> cols_sql
  <> ") values ("
  <> placeholders
  <> ") on conflict ("
  <> migration_sql.quote_ident(root_fk)
  <> ", "
  <> migration_sql.quote_ident(target_fk)
  <> ") do update set "
  <> update_clause
  <> ";"
}

fn gleam_escape_string(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
}

fn junction_upsert_gleam_fn(spec: JunctionSpec) -> String {
  let jt =
    string.lowercase(spec.root_entity)
    <> "_"
    <> string.lowercase(spec.target_entity)
  let fn_name = "upsert_" <> jt
  let sql_const = fn_name <> "_sql"
  let root_fk = string.lowercase(spec.root_entity) <> "_id"
  let target_fk = string.lowercase(spec.target_entity) <> "_id"
  let id_params = [
    root_fk <> " " <> root_fk <> ": Int",
    target_fk <> " " <> target_fk <> ": Int",
  ]
  let edge_params =
    list.map(spec.edge_fields, fn(f) {
      f.label <> " " <> f.label <> ": " <> junction_gleam_type(f.type_)
    })
  let all_params =
    list.flatten([["conn: sqlight.Connection"], id_params, edge_params])
  let id_binds = [
    "sqlight.int(" <> root_fk <> ")",
    "sqlight.int(" <> target_fk <> ")",
  ]
  let edge_binds =
    list.map(spec.edge_fields, fn(f) { junction_sqlight_bind(f.label, f.type_) })
  let all_binds = list.append(id_binds, edge_binds)
  "pub fn "
  <> fn_name
  <> "(\n  "
  <> string.join(all_params, ",\n  ")
  <> ",\n) -> Result(Nil, sqlight.Error) {\n  sqlight.query(\n    "
  <> sql_const
  <> ",\n    on: conn,\n    with: ["
  <> string.join(all_binds, ", ")
  <> "],\n    expecting: decode.success(Nil),\n  )\n  |> result.map(fn(_) { Nil })\n}"
}

fn junction_table_ident(spec: JunctionSpec) -> String {
  string.lowercase(spec.root_entity)
  <> "_"
  <> string.lowercase(spec.target_entity)
}

fn junction_fk_names(spec: JunctionSpec) -> #(String, String) {
  #(
    string.lowercase(spec.root_entity) <> "_id",
    string.lowercase(spec.target_entity) <> "_id",
  )
}

/// Non-unique index on `(root_id, target_id, …edge columns)` for filter EXISTS lookups.
fn junction_perf_index_name(spec: JunctionSpec) -> String {
  let jt = junction_table_ident(spec)
  let #(root_fk, target_fk) = junction_fk_names(spec)
  let parts =
    list.flatten([
      [root_fk, target_fk],
      list.map(spec.edge_fields, fn(f) { f.label }),
    ])
  jt <> "_by_" <> string.join(parts, "_")
}

fn junction_perf_index_create_sql(spec: JunctionSpec) -> String {
  let jt = junction_table_ident(spec)
  let iname = junction_perf_index_name(spec)
  let #(root_fk, target_fk) = junction_fk_names(spec)
  let col_names =
    list.flatten([
      [root_fk, target_fk],
      list.map(spec.edge_fields, fn(f) { f.label }),
    ])
  let cols_sql =
    list.map(col_names, migration_sql.quote_ident) |> string.join(", ")
  "create index "
  <> iname
  <> " on "
  <> migration_sql.quote_ident(jt)
  <> "("
  <> cols_sql
  <> ");"
}

fn junction_sqlite_autoindex_name(jt: String) -> String {
  "sqlite_autoindex_" <> jt <> "_1"
}

fn junction_expected_index_list_tsv(spec: JunctionSpec) -> String {
  let jt = junction_table_ident(spec)
  let perf = junction_perf_index_name(spec)
  let auto_ix = junction_sqlite_autoindex_name(jt)
  "seq\tname\tunique\torigin\tpartial\n0\t"
  <> perf
  <> "\t0\tc\t0\n1\t"
  <> auto_ix
  <> "\t1\tu\t0"
}

fn junction_expected_perf_index_info_tsv(spec: JunctionSpec) -> String {
  let header = "seqno\tcid\tname"
  let #(root_fk, target_fk) = junction_fk_names(spec)
  let row0 = "0\t0\t" <> root_fk
  let row1 = "1\t1\t" <> target_fk
  let edge_rows =
    list.index_map(spec.edge_fields, fn(f, i) {
      int.to_string(i + 2) <> "\t" <> int.to_string(i + 2) <> "\t" <> f.label
    })
  string.join([header, row0, row1, ..edge_rows], "\n")
}

fn junction_expected_unique_index_info_tsv(spec: JunctionSpec) -> String {
  let #(root_fk, target_fk) = junction_fk_names(spec)
  "seqno\tcid\tname\n0\t0\t" <> root_fk <> "\n1\t1\t" <> target_fk
}

fn junction_perf_index_const_name(spec: JunctionSpec) -> String {
  "create_" <> junction_table_ident(spec) <> "_perf_index_sql"
}

fn junction_expected_list_const(spec: JunctionSpec) -> String {
  "expected_" <> junction_table_ident(spec) <> "_index_list"
}

fn junction_expected_perf_info_const(spec: JunctionSpec) -> String {
  "expected_" <> junction_table_ident(spec) <> "_perf_index_info"
}

fn junction_expected_unique_info_const(spec: JunctionSpec) -> String {
  "expected_" <> junction_table_ident(spec) <> "_unique_index_info"
}

fn junction_drop_surplus_fn_name(spec: JunctionSpec) -> String {
  "drop_surplus_user_indexes_on_" <> junction_table_ident(spec)
}

fn junction_ensure_indexes_fn_name(spec: JunctionSpec) -> String {
  "ensure_" <> junction_table_ident(spec) <> "_indexes"
}

fn junction_perf_index_gleam_block(spec: JunctionSpec) -> String {
  let jt = junction_table_ident(spec)
  let perf = junction_perf_index_name(spec)
  let create_sql = junction_perf_index_create_sql(spec)
  let list_tsv = junction_expected_index_list_tsv(spec)
  let perf_info = junction_expected_perf_index_info_tsv(spec)
  let unique_info = junction_expected_unique_index_info_tsv(spec)
  let c_create = junction_perf_index_const_name(spec)
  let c_list = junction_expected_list_const(spec)
  let c_perf = junction_expected_perf_info_const(spec)
  let c_unique = junction_expected_unique_info_const(spec)
  let fn_drop = junction_drop_surplus_fn_name(spec)
  let fn_ensure = junction_ensure_indexes_fn_name(spec)
  let auto_ix = junction_sqlite_autoindex_name(jt)
  string.join(
    [
      "/// Seek `(…)` on junction `"
        <> jt
        <> "` for filter `EXISTS` subqueries.",
      "const " <> c_create <> " = \"" <> gleam_escape_string(create_sql) <> "\"",
      "",
      "const " <> c_list <> " = \"" <> gleam_escape_string(list_tsv) <> "\"",
      "",
      "const " <> c_perf <> " = \"" <> gleam_escape_string(perf_info) <> "\"",
      "",
      "const "
        <> c_unique
        <> " = \""
        <> gleam_escape_string(unique_info)
        <> "\"",
      "",
      "fn "
        <> fn_drop
        <> "(\n  conn: sqlight.Connection,\n) -> Result(Nil, sqlight.Error) {",
      "  use rows <- result.try(pragma_index_name_origin_rows(conn, \""
        <> jt
        <> "\"))",
      "  list.try_each(rows, fn(pair) {",
      "    let #(name, origin) = pair",
      "    case origin == \"c\" && name != \"" <> perf <> "\" {",
      "      True -> sqlight.exec(\"drop index if exists \" <> name <> \";\", conn)",
      "      False -> Ok(Nil)",
      "    }",
      "  })",
      "}",
      "",
      "fn "
        <> fn_ensure
        <> "(\n  conn: sqlight.Connection,\n) -> Result(Nil, sqlight.Error) {",
      "  use _ <- result.try(" <> fn_drop <> "(conn))",
      "  case",
      "    sqlite_pragma_assert.index_list_tsv(conn, \"" <> jt <> "\"),",
      "    sqlite_pragma_assert.index_info_tsv(conn, \"" <> perf <> "\"),",
      "    sqlite_pragma_assert.index_info_tsv(conn, \"" <> auto_ix <> "\")",
      "  {",
      "    Ok(list_tsv), Ok(perf_info), Ok(unique_info) ->",
      "      case",
      "        list_tsv == "
        <> c_list
        <> " && perf_info == "
        <> c_perf
        <> " && unique_info == "
        <> c_unique,
      "      {",
      "        True -> Ok(Nil)",
      "        False -> {",
      "          use _ <- result.try(sqlight.exec(",
      "            \"drop index if exists " <> perf <> ";\",",
      "            conn,",
      "          ))",
      "          sqlight.exec(" <> c_create <> ", conn)",
      "        }",
      "      }",
      "    _, _, _ -> {",
      "      use _ <- result.try(sqlight.exec(",
      "        \"drop index if exists " <> perf <> ";\",",
      "        conn,",
      "      ))",
      "      sqlight.exec(" <> c_create <> ", conn)",
      "    }",
      "  }",
      "}",
    ],
    "\n",
  )
}

fn build_create_junction_tables_fn(specs: List(JunctionSpec)) -> String {
  let lines =
    list.map(specs, fn(spec) {
      let jt = junction_table_ident(spec)
      let create_line =
        "  use _ <- result.try(sqlight.exec(create_" <> jt <> "_sql, conn))"
      case spec.edge_fields {
        [] -> create_line
        _ -> {
          let ensure = junction_ensure_indexes_fn_name(spec)
          create_line <> "\n  use _ <- result.try(" <> ensure <> "(conn))"
        }
      }
    })
  "fn create_junction_tables(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {\n"
  <> string.join(lines, "\n")
  <> "\n  Ok(Nil)\n}"
}

fn generate_junction_table_appendage_inner(schema: SchemaDefinition) -> String {
  let specs = find_junction_specs(schema)
  case specs {
    [] -> ""
    _ -> {
      let parts =
        list.map(specs, fn(spec) {
          let jt = junction_table_ident(spec)
          let create_const = "create_" <> jt <> "_sql"
          let consts =
            "const "
            <> create_const
            <> " =\n  \""
            <> gleam_escape_string(junction_ddl_sql(spec))
            <> "\""
          let perf = case spec.edge_fields {
            [] -> ""
            _ -> "\n\n" <> junction_perf_index_gleam_block(spec)
          }
          consts <> perf
        })
      let create_fn = build_create_junction_tables_fn(specs)
      "\n\n" <> create_fn <> "\n\n" <> string.join(parts, "\n\n")
    }
  }
}

/// Gleam source for junction upsert SQL constants and `pub fn upsert_*` (appended to `*_db/cmd.gleam`).
pub fn generate_junction_upserts_gleam_appendage(
  schema: SchemaDefinition,
) -> String {
  let specs = find_junction_specs(schema)
  case specs {
    [] -> ""
    _ -> {
      let parts =
        list.map(specs, fn(spec) {
          let jt = junction_table_ident(spec)
          let upsert_const = "upsert_" <> jt <> "_sql"
          "const "
          <> upsert_const
          <> " =\n  \""
          <> gleam_escape_string(junction_upsert_sql(spec))
          <> "\"\n\n"
          <> junction_upsert_gleam_fn(spec)
        })
      "\n\n" <> string.join(parts, "\n\n")
    }
  }
}

fn inject_junction_tables_call(migration_text: String) -> String {
  let suffix = "\n  Ok(Nil)\n}\n"
  case string.ends_with(migration_text, suffix) {
    False -> migration_text
    True -> {
      let before = string.drop_end(migration_text, string.length(suffix))
      before
      <> "\n  use _ <- result.try(create_junction_tables(conn))\n  Ok(Nil)\n}\n"
    }
  }
}

/// Full Gleam module text for pragma reconcile migrations: one module per schema,
/// single- or multi-entity.
/// [module_tag] is baked into panic messages so failures name the generating module.
pub fn generate_pragma_migration_module(
  schema: SchemaDefinition,
  module_tag: String,
) -> Result(String, String) {
  let entities =
    list.sort(schema.entities, fn(a, b) {
      string.compare(a.type_name, b.type_name)
    })
  let multi_entity = list.length(entities) > 1
  let datas =
    list.map(entities, fn(e) {
      build_pragma_migration_data_for_entity(
        schema,
        e,
        module_tag,
        multi_entity,
      )
    })
  let unformatted = case multi_entity {
    False -> {
      let assert [d] = datas
      pragma_migration_emit.emit(d)
    }
    True -> pragma_migration_emit.emit_multi(datas)
  }
  gleam_fmt.format_generated_source(unformatted)
}

/// Like `generate_pragma_migration_module` but also appends junction table DDL
/// and helper functions for every `List(BelongsTo(...))` relationship in the schema.
pub fn generate_pragma_migration_module_with_junctions(
  schema: SchemaDefinition,
  module_tag: String,
) -> Result(String, String) {
  use base_text <- result.try(generate_pragma_migration_module(
    schema,
    module_tag,
  ))
  let appendage = generate_junction_table_appendage_inner(schema)
  case appendage {
    "" -> Ok(base_text)
    _ -> {
      let modified = inject_junction_tables_call(base_text) <> appendage
      gleam_fmt.format_generated_source(modified)
    }
  }
}
