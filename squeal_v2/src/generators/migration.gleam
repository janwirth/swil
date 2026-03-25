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

fn entity_table_name(entity_type: String) -> String {
  string.lowercase(entity_type)
}

fn type_is_list(t: glance.Type) -> Bool {
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

fn pragma_affinity_upper(type_: glance.Type) -> String {
  case ddl_sql_type(type_) {
    "integer" -> "INTEGER"
    "text" -> "TEXT"
    "real" -> "REAL"
    _ -> "TEXT"
  }
}

fn build_create_table_sql(table: String, data_fields: List(FieldDefinition)) -> String {
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

fn build_expected_table_info(rows: List(#(String, String, Int, Int))) -> String {
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

fn label_to_cid(full: List(String), label: String) -> Int {
  let assert Ok(#(i, _)) =
    full
    |> list.index_map(fn(name, idx) { #(idx, name) })
    |> list.find(fn(p) { p.1 == label })
  i
}

fn build_expected_index_info(
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

fn gleam_quote(s: String) -> String {
  "\"" <> s <> "\""
}

/// Gleam source for a single-entity pragma reconcile blueprint like
/// `example_migration_fruit` / `example_migration_animal`. [module_tag] appears in
/// panic strings (e.g. `example_migration_fruit`).
pub fn generate_pragma_migration_module(
  schema: SchemaDefinition,
  module_tag: String,
) -> String {
  let assert [entity] = schema.entities
  let table = entity_table_name(entity.type_name)
  let col_type = entity.type_name <> "Col"
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
  let index_cols = list.map(variant.fields, fn(f) { f.label }) |> string.join(", ")
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
    "seq\tname\tunique\torigin\tpartial\n0\t"
    <> index_name
    <> "\t1\tc\t0"
  let expected_index_info =
    build_expected_index_info(variant.fields, full_col_names)
  let columns_wanted_lines =
    wanted_rows
    |> list.map(fn(row) {
      let #(n, t, nn, pk) = row
      "  "
      <> col_type
      <> "("
      <> gleam_quote(n)
      <> ", "
      <> gleam_quote(t)
      <> ", "
      <> int.to_string(nn)
      <> ", "
      <> int.to_string(pk)
      <> "),"
    })
    |> string.join("\n")
  let conn_t = "(conn, " <> gleam_quote(table) <> ")"
  let conn_index = "(conn, " <> gleam_quote(index_name) <> ")"
  let panic_no_fix = gleam_quote(module_tag <> ": no column fix applies")
  let panic_no_conv = gleam_quote(module_tag <> ": column reconcile did not converge")

  string.join(
    [
      "//// Blueprint for a generated `migrate`: introspect user tables and `"
        <> table
        <> "` columns /",
      "//// indexes, then move to the desired state using `ALTER TABLE` only (add / drop column),",
      "//// never `DROP TABLE` / `CREATE TABLE` for shape fixes once `"
        <> table
        <> "` exists.",
      "import gleam/dynamic/decode",
      "import gleam/list",
      "import gleam/option.{type Option, None, Some}",
      "import gleam/result",
      "import gleam/string",
      "import sqlite_pragma_assert.{type TableInfoRow}",
      "import sqlight",
      "",
      "const create_"
        <> table
        <> "_table_sql = \""
        <> create_table_sql
        <> "\"",
      "",
      "const create_"
        <> table
        <> "_by_"
        <> index_suffix
        <> "_index_sql =",
      "  \"" <> create_index_sql <> "\"",
      "",
      "const expected_table_info = \"" <> expected_table_info <> "\"",
      "",
      "const expected_index_list = \"" <> expected_index_list <> "\"",
      "",
      "const expected_index_info = \"" <> expected_index_info <> "\"",
      "",
      "type " <> col_type <> " {",
      "  "
        <> col_type
        <> "(name: String, type_: String, notnull: Int, pk: Int)",
      "}",
      "",
      "const "
        <> table
        <> "_columns_wanted = [",
      columns_wanted_lines,
      "]",
      "",
      "fn pragma_index_name_origin_rows(",
      "  conn: sqlight.Connection,",
      "  table: String,",
      ") -> Result(List(#(String, String)), sqlight.Error) {",
      "  sqlight.query(",
      "    \"pragma index_list(\" <> table <> \")\",",
      "    on: conn,",
      "    with: [],",
      "    expecting: {",
      "      use name <- decode.field(1, decode.string)",
      "      use origin <- decode.field(3, decode.string)",
      "      decode.success(#(name, origin))",
      "    },",
      "  )",
      "}",
      "",
      "fn drop_surplus_user_indexes_on_"
        <> table
        <> "(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {",
      "  use rows <- result.try(pragma_index_name_origin_rows"
        <> conn_t
        <> ")",
      "  list.try_each(rows, fn(pair) {",
      "    let #(name, origin) = pair",
      "    case origin == "
        <> gleam_quote("c")
        <> " && name != "
        <> gleam_quote(index_name)
        <> " {",
      "      True -> sqlight.exec(\"drop index if exists \" <> name <> \";\", conn)",
      "      False -> Ok(Nil)",
      "    }",
      "  })",
      "}",
      "",
      "fn type_matches(expected: String, got: String) -> Bool {",
      "  string.uppercase(got) == expected",
      "}",
      "",
      "fn "
        <> table
        <> "_row_matches(want: "
        <> col_type
        <> ", got: TableInfoRow) -> Bool {",
      "  want.name == got.name",
      "  && type_matches(want.type_, got.type_)",
      "  && want.notnull == got.notnull",
      "  && want.pk == got.pk",
      "  && case want.notnull {",
      "    0 -> got.dflt == None || got.dflt == Some(\"\")",
      "    _ -> True",
      "  }",
      "}",
      "",
      "fn first_surplus_column(",
      "  rows: List(TableInfoRow),",
      "  wanted: List(" <> col_type <> "),",
      ") -> Option(String) {",
      "  case",
      "    list.find(rows, fn(r) {",
      "      !list.any(wanted, fn(w) { w.name == r.name })",
      "    })",
      "  {",
      "    Ok(r) -> Some(r.name)",
      "    Error(Nil) -> None",
      "  }",
      "}",
      "",
      "fn first_mismatched_column_name(",
      "  rows: List(TableInfoRow),",
      "  wanted: List(" <> col_type <> "),",
      ") -> Option(String) {",
      "  case",
      "    list.find_map(wanted, fn(w) {",
      "      case list.find(rows, fn(r) { r.name == w.name }) {",
      "        Error(Nil) -> Error(Nil)",
      "        Ok(row) ->",
      "          case "
        <> table
        <> "_row_matches(w, row) {",
      "            True -> Error(Nil)",
      "            False -> Ok(w.name)",
      "          }",
      "      }",
      "    })",
      "  {",
      "    Ok(name) -> Some(name)",
      "    Error(Nil) -> None",
      "  }",
      "}",
      "",
      "fn first_missing_column(",
      "  rows: List(TableInfoRow),",
      "  wanted: List(" <> col_type <> "),",
      ") -> Option(" <> col_type <> ") {",
      "  case",
      "    list.find(wanted, fn(w) {",
      "      !list.any(rows, fn(r) { r.name == w.name })",
      "    })",
      "  {",
      "    Ok(w) -> Some(w)",
      "    Error(Nil) -> None",
      "  }",
      "}",
      "",
      "fn alter_add_"
        <> table
        <> "_column_sql(w: "
        <> col_type
        <> ") -> String {",
      "  let fragment = case w.name {",
      "    \"id\" -> \"integer primary key autoincrement not null\"",
      "    \"deleted_at\" -> \"integer\"",
      "    _ ->",
      "      case string.uppercase(w.type_) {",
      "        \"INTEGER\" -> \"integer\"",
      "        \"TEXT\" -> \"text\"",
      "        \"REAL\" -> \"real\"",
      "        _ -> \"text\"",
      "      }",
      "      <> case w.notnull {",
      "        1 -> \" not null\"",
      "        _ -> \"\"",
      "      }",
      "  }",
      "  \"alter table "
        <> table
        <> " add column \" <> w.name <> \" \" <> fragment <> \";\"",
      "}",
      "",
      "fn apply_one_"
        <> table
        <> "_column_fix(",
      "  conn: sqlight.Connection,",
      "  rows: List(TableInfoRow),",
      ") -> Result(Nil, sqlight.Error) {",
      "  case first_surplus_column(rows, "
        <> table
        <> "_columns_wanted) {",
      "    Some(name) ->",
      "      sqlight.exec(\"alter table "
        <> table
        <> " drop column \" <> name <> \";\", conn)",
      "    None ->",
      "      case first_mismatched_column_name(rows, "
        <> table
        <> "_columns_wanted) {",
      "        Some(name) ->",
      "          sqlight.exec(\"alter table "
        <> table
        <> " drop column \" <> name <> \";\", conn)",
      "        None ->",
      "          case first_missing_column(rows, "
        <> table
        <> "_columns_wanted) {",
      "            Some(w) -> sqlight.exec(alter_add_"
        <> table
        <> "_column_sql(w), conn)",
      "            None -> panic as " <> panic_no_fix,
      "          }",
      "      }",
      "  }",
      "}",
      "",
      "fn reconcile_"
        <> table
        <> "_columns_loop(",
      "  conn: sqlight.Connection,",
      "  iter: Int,",
      ") -> Result(Nil, sqlight.Error) {",
      "  case iter > 64 {",
      "    True ->",
      "      panic as " <> panic_no_conv,
      "    False -> {",
      "      use rows <- result.try(sqlite_pragma_assert.table_info_rows"
        <> conn_t
        <> ")",
      "      case",
      "        list.length(rows) == list.length("
        <> table
        <> "_columns_wanted)",
      "        && list.all("
        <> table
        <> "_columns_wanted, fn(w) {",
      "          case list.find(rows, fn(r) { r.name == w.name }) {",
      "            Ok(row) -> "
        <> table
        <> "_row_matches(w, row)",
      "            Error(Nil) -> False",
      "          }",
      "        })",
      "      {",
      "        True -> Ok(Nil)",
      "        False -> {",
      "          use _ <- result.try(apply_one_"
        <> table
        <> "_column_fix(conn, rows))",
      "          reconcile_" <> table <> "_columns_loop(conn, iter + 1)",
      "        }",
      "      }",
      "    }",
      "  }",
      "}",
      "",
      "fn ensure_"
        <> table
        <> "_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {",
      "  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))",
      "  case list.contains(tables, "
        <> gleam_quote(table)
        <> ") {",
      "    False -> sqlight.exec(create_" <> table <> "_table_sql, conn)",
      "    True -> reconcile_" <> table <> "_columns_loop(conn, 0)",
      "  }",
      "}",
      "",
      "fn ensure_"
        <> table
        <> "_indexes(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {",
      "  use _ <- result.try(drop_surplus_user_indexes_on_" <> table <> "(conn))",
      "  case",
      "    sqlite_pragma_assert.index_list_tsv"
        <> conn_t
        <> ",",
      "    sqlite_pragma_assert.index_info_tsv" <> conn_index,
      "  {",
      "    Ok(list_tsv), Ok(info_tsv) ->",
      "      case list_tsv == expected_index_list && info_tsv == expected_index_info {",
      "        True -> Ok(Nil)",
      "        False -> {",
      "          use _ <- result.try(sqlight.exec(",
      "            \"drop index if exists "
        <> index_name
        <> ";\",",
      "            conn,",
      "          ))",
      "          sqlight.exec(create_"
        <> table
        <> "_by_"
        <> index_suffix
        <> "_index_sql, conn)",
      "        }",
      "      }",
      "    _, _ -> {",
      "      use _ <- result.try(sqlight.exec(",
      "        \"drop index if exists "
        <> index_name
        <> ";\",",
      "        conn,",
      "      ))",
      "      sqlight.exec(create_"
        <> table
        <> "_by_"
        <> index_suffix
        <> "_index_sql, conn)",
      "    }",
      "  }",
      "}",
      "",
      "/// Applies this version: remove non-"
        <> table
        <> " user tables, align `"
        <> table
        <> "` columns and",
      "/// identity indexes to the expected shape, then verify with pragmas.",
      "pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {",
      "  use _ <- result.try(sqlite_pragma_assert.drop_user_tables_except"
        <> conn_t
        <> ")",
      "  use _ <- result.try(ensure_" <> table <> "_table(conn))",
      "  use _ <- result.try(ensure_" <> table <> "_indexes(conn))",
      "  sqlite_pragma_assert.assert_pragma_snapshot(",
      "    conn,",
      "    [" <> gleam_quote(table) <> "],",
      "    " <> gleam_quote(table) <> ",",
      "    expected_table_info,",
      "    expected_index_list,",
      "    " <> gleam_quote(index_name) <> ",",
      "    expected_index_info,",
      "  )",
      "  Ok(Nil)",
      "}",
    ],
    "\n",
  )
  <> "\n"
}
