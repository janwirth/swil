import generators/migration/pragma_migration_data.{
  type PragmaMigrationData, columns_wanted_block,
}
import gleam/list
import gleam/string

pub fn emit(data: PragmaMigrationData) -> String {
  let body =
    module_lines(data)
    |> string.join("\n")
  case string.ends_with(body, "\n") {
    True -> body
    False -> string.append(body, "\n")
  }
}

fn q(s: String) -> String {
  string.concat(["\"", s, "\""])
}

fn columns_const(data: PragmaMigrationData) -> List(String) {
  list.flatten([
    [string.concat(["const ", data.table, "_columns_wanted = ["])],
    string.split(columns_wanted_block(data), "\n"),
    ["]", ""],
  ])
}

fn module_lines(data: PragmaMigrationData) -> List(String) {
  let conn_t = string.concat(["(conn, ", q(data.table), ")"])
  let conn_index = string.concat(["(conn, ", q(data.index_name), ")"])
  let reconcile_stmt_lines =
    string.split(data.reconcile_table_info_rows_stmt, "\n")
  list.flatten([
    [
      string.concat([
        "//// Blueprint for a generated `migrate`: introspect user tables and `",
        data.table,
        "` columns /",
      ]),
      "//// indexes, then move to the desired state using `ALTER TABLE` only (add / drop column),",
      string.concat([
        "//// never `DROP TABLE` / `CREATE TABLE` for shape fixes once `",
        data.table,
        "` exists.",
      ]),
      "",
    ],
    [
      "import gleam/dynamic/decode",
      "import gleam/list",
      "import gleam/option.{type Option, None, Some}",
      "import gleam/result",
      "import gleam/string",
      "import sqlight",
      "import sqlite_pragma_assert.{type TableInfoRow}",
      "",
    ],
    [
      string.concat([
        "const create_",
        data.table,
        "_table_sql = \"",
        data.create_table_sql,
        "\"",
      ]),
      "",
      string.concat([
        "const create_",
        data.table,
        "_by_",
        data.index_suffix,
        "_index_sql = \"",
        data.create_index_sql,
        "\"",
      ]),
      "",
      string.concat([
        "const expected_table_info = \"",
        data.expected_table_info,
        "\"",
      ]),
      "",
      string.concat([
        "const expected_index_list = \"",
        data.expected_index_list,
        "\"",
      ]),
      "",
      string.concat([
        "const expected_index_info = \"",
        data.expected_index_info,
        "\"",
      ]),
      "",
      string.concat(["type ", data.col_type, " {"]),
      string.concat([
        "  ",
        data.col_type,
        "(name: String, type_: String, notnull: Int, pk: Int)",
      ]),
      "}",
      "",
    ],
    columns_const(data),
    pragma_index_lines(),
    [""],
    drop_surplus_lines(data, conn_t),
    [""],
    type_matches_lines(),
    [""],
    row_matches_lines(data),
    [""],
    first_surplus_lines(data),
    [""],
    first_mismatched_lines(data),
    [""],
    first_missing_lines(data),
    [""],
    alter_add_lines(data),
    [""],
    apply_one_lines(data),
    [""],
    reconcile_loop_lines(data, reconcile_stmt_lines),
    [""],
    ensure_table_lines(data),
    [""],
    ensure_indexes_lines(data, conn_t, conn_index),
    [""],
    migration_pub_lines(data),
  ])
}

fn pragma_index_lines() -> List(String) {
  [
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
  ]
}

fn drop_surplus_lines(data: PragmaMigrationData, conn_t: String) -> List(String) {
  [
    string.concat(["fn drop_surplus_user_indexes_on_", data.table, "("]),
    "  conn: sqlight.Connection,",
    ") -> Result(Nil, sqlight.Error) {",
    string.concat([
      "  use rows <- result.try(pragma_index_name_origin_rows",
      conn_t,
      ")",
    ]),
    "  list.try_each(rows, fn(pair) {",
    "    let #(name, origin) = pair",
    string.concat([
      "    case origin == ",
      q("c"),
      " && name != ",
      q(data.index_name),
      " {",
    ]),
    "      True -> sqlight.exec(\"drop index if exists \" <> name <> \";\", conn)",
    "      False -> Ok(Nil)",
    "    }",
    "  })",
    "}",
  ]
}

fn type_matches_lines() -> List(String) {
  [
    "fn type_matches(expected: String, got: String) -> Bool {",
    "  string.uppercase(got) == expected",
    "}",
  ]
}

fn row_matches_lines(data: PragmaMigrationData) -> List(String) {
  [
    string.concat([
      "fn ",
      data.table,
      "_row_matches(want: ",
      data.col_type,
      ", got: TableInfoRow) -> Bool {",
    ]),
    "  want.name == got.name",
    "  && type_matches(want.type_, got.type_)",
    "  && want.notnull == got.notnull",
    "  && want.pk == got.pk",
    "  && case want.notnull {",
    "    0 -> got.dflt == None || got.dflt == Some(\"\")",
    "    _ -> True",
    "  }",
    "}",
  ]
}

fn wanted_list(data: PragmaMigrationData) -> String {
  string.concat([data.table, "_columns_wanted"])
}

fn first_surplus_lines(data: PragmaMigrationData) -> List(String) {
  [
    "fn first_surplus_column(",
    "  rows: List(TableInfoRow),",
    string.concat([
      "  wanted: List(",
      data.col_type,
      "),",
    ]),
    ") -> Option(String) {",
    "  case",
    "    list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) })",
    "  {",
    "    Ok(r) -> Some(r.name)",
    "    Error(Nil) -> None",
    "  }",
    "}",
  ]
}

fn first_mismatched_lines(data: PragmaMigrationData) -> List(String) {
  let row_match = string.concat([data.table, "_row_matches"])
  [
    "fn first_mismatched_column_name(",
    "  rows: List(TableInfoRow),",
    string.concat([
      "  wanted: List(",
      data.col_type,
      "),",
    ]),
    ") -> Option(String) {",
    "  case",
    "    list.find_map(wanted, fn(w) {",
    "      case list.find(rows, fn(r) { r.name == w.name }) {",
    "        Error(Nil) -> Error(Nil)",
    "        Ok(row) ->",
    string.concat(["          case ", row_match, "(w, row) {"]),
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
  ]
}

fn first_missing_lines(data: PragmaMigrationData) -> List(String) {
  [
    "fn first_missing_column(",
    "  rows: List(TableInfoRow),",
    string.concat([
      "  wanted: List(",
      data.col_type,
      "),",
    ]),
    string.concat([
      ") -> Option(",
      data.col_type,
      ") {",
    ]),
    "  case",
    "    list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) })",
    "  {",
    "    Ok(w) -> Some(w)",
    "    Error(Nil) -> None",
    "  }",
    "}",
  ]
}

fn alter_add_lines(data: PragmaMigrationData) -> List(String) {
  [
    string.concat([
      "fn alter_add_",
      data.table,
      "_column_sql(w: ",
      data.col_type,
      ") -> String {",
    ]),
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
    string.concat([
      "  \"alter table ",
      data.table,
      " add column \" <> w.name <> \" \" <> fragment <> \";\"",
    ]),
    "}",
  ]
}

fn apply_one_lines(data: PragmaMigrationData) -> List(String) {
  let wl = wanted_list(data)
  let alter_fn = string.concat(["alter_add_", data.table, "_column_sql"])
  let apply_fn = string.concat(["apply_one_", data.table, "_column_fix"])
  let none_panic_lines = string.split(data.apply_one_none_panic, "\n")
  list.flatten([
    [
      string.concat(["fn ", apply_fn, "("]),
      "  conn: sqlight.Connection,",
      "  rows: List(TableInfoRow),",
      ") -> Result(Nil, sqlight.Error) {",
      string.concat(["  case first_surplus_column(rows, ", wl, ") {"]),
      "    Some(name) ->",
      string.concat([
        "      sqlight.exec(\"alter table ",
        data.table,
        " drop column \" <> name <> \";\", conn)",
      ]),
      "    None ->",
      string.concat([
        "      case first_mismatched_column_name(rows, ",
        wl,
        ") {",
      ]),
      "        Some(name) ->",
      string.concat([
        "          sqlight.exec(\"alter table ",
        data.table,
        " drop column \" <> name <> \";\", conn)",
      ]),
      "        None ->",
      string.concat(["          case first_missing_column(rows, ", wl, ") {"]),
      string.concat([
        "            Some(w) -> sqlight.exec(",
        alter_fn,
        "(w), conn)",
      ]),
    ],
    none_panic_lines,
    [
      "          }",
      "      }",
      "  }",
      "}",
    ],
  ])
}

fn reconcile_loop_lines(
  data: PragmaMigrationData,
  reconcile_stmt_lines: List(String),
) -> List(String) {
  let wl = wanted_list(data)
  let row_match = string.concat([data.table, "_row_matches"])
  let apply_fn = string.concat(["apply_one_", data.table, "_column_fix"])
  let loop_fn = string.concat(["reconcile_", data.table, "_columns_loop"])

  list.flatten([
    [
      string.concat(["fn ", loop_fn, "("]),
      "  conn: sqlight.Connection,",
      "  iter: Int,",
      ") -> Result(Nil, sqlight.Error) {",
      "  case iter > 64 {",
      "    True ->",
      string.concat(["      panic as ", data.panic_no_conv]),
      "    False -> {",
    ],
    reconcile_stmt_lines,
    [
      "      case",
      string.concat([
        "        list.length(rows) == list.length(",
        wl,
        ")",
      ]),
      string.concat([
        "        && list.all(",
        wl,
        ", fn(w) {",
      ]),
      "          case list.find(rows, fn(r) { r.name == w.name }) {",
      string.concat(["            Ok(row) -> ", row_match, "(w, row)"]),
      "            Error(Nil) -> False",
      "          }",
      "        })",
      "      {",
      "        True -> Ok(Nil)",
      "        False -> {",
      string.concat([
        "          use _ <- result.try(",
        apply_fn,
        "(conn, rows))",
      ]),
      string.concat(["          ", loop_fn, "(conn, iter + 1)"]),
      "        }",
      "      }",
      "    }",
      "  }",
      "}",
    ],
  ])
}

fn ensure_table_lines(data: PragmaMigrationData) -> List(String) {
  let loop_fn = string.concat(["reconcile_", data.table, "_columns_loop"])
  let ensure_fn = string.concat(["ensure_", data.table, "_table"])
  [
    string.concat([
      "fn ",
      ensure_fn,
      "(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {",
    ]),
    "  use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))",
    string.concat(["  case list.contains(tables, ", q(data.table), ") {"]),
    string.concat([
      "    False -> sqlight.exec(create_",
      data.table,
      "_table_sql, conn)",
    ]),
    string.concat(["    True -> ", loop_fn, "(conn, 0)"]),
    "  }",
    "}",
  ]
}

fn ensure_indexes_lines(
  data: PragmaMigrationData,
  conn_t: String,
  conn_index: String,
) -> List(String) {
  let ensure_fn = string.concat(["ensure_", data.table, "_indexes"])
  let drop_surplus_fn =
    string.concat(["drop_surplus_user_indexes_on_", data.table])
  let create_idx =
    string.concat([
      "create_",
      data.table,
      "_by_",
      data.index_suffix,
      "_index_sql",
    ])
  [
    string.concat([
      "fn ",
      ensure_fn,
      "(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {",
    ]),
    string.concat([
      "  use _ <- result.try(",
      drop_surplus_fn,
      "(conn))",
    ]),
    "  case",
    string.concat([
      "    sqlite_pragma_assert.index_list_tsv",
      conn_t,
      ",",
    ]),
    string.concat([
      "    sqlite_pragma_assert.index_info_tsv",
      conn_index,
    ]),
    "  {",
    "    Ok(list_tsv), Ok(info_tsv) ->",
    "      case list_tsv == expected_index_list && info_tsv == expected_index_info {",
    "        True -> Ok(Nil)",
    "        False -> {",
    "          use _ <- result.try(sqlight.exec(",
    string.concat([
      "            \"drop index if exists ",
      data.index_name,
      ";\",",
    ]),
    "            conn,",
    "          ))",
    string.concat(["          sqlight.exec(", create_idx, ", conn)"]),
    "        }",
    "      }",
    "    _, _ -> {",
    "      use _ <- result.try(sqlight.exec(",
    string.concat([
      "        \"drop index if exists ",
      data.index_name,
      ";\",",
    ]),
    "        conn,",
    "      ))",
    string.concat(["      sqlight.exec(", create_idx, ", conn)"]),
    "    }",
    "  }",
    "}",
  ]
}

fn migration_pub_lines(data: PragmaMigrationData) -> List(String) {
  let ensure_t = string.concat(["ensure_", data.table, "_table"])
  let ensure_i = string.concat(["ensure_", data.table, "_indexes"])
  list.flatten([
    [
      string.concat([
        "/// Applies this version: remove non-",
        data.table,
        " user tables, align `",
        data.table,
        "` columns and",
      ]),
      "/// identity indexes to the expected shape, then verify with pragmas.",
      string.concat([
        "pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {",
      ]),
      "  use _ <- result.try(sqlite_pragma_assert.drop_user_tables_except(",
      "    conn,",
      string.concat(["    ", q(data.table), ","]),
      "  ))",
      string.concat(["  use _ <- result.try(", ensure_t, "(conn))"]),
      string.concat(["  use _ <- result.try(", ensure_i, "(conn))"]),
      "  sqlite_pragma_assert.assert_pragma_snapshot(",
      "    conn,",
      string.concat(["    [", q(data.table), "],"]),
      string.concat(["    ", q(data.table), ","]),
      "    expected_table_info,",
      "    expected_index_list,",
      string.concat(["    ", q(data.index_name), ","]),
      "    expected_index_info,",
      "  )",
      "  Ok(Nil)",
      "}",
    ],
  ])
}
