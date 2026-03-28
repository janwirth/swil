import generators/migration/pragma_migration_data.{type PragmaMigrationData}
import gleam/list
import gleam/option
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/expression/constructor as gconstructor
import gleamgen/function as gfun
import gleamgen/import_ as gimport
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/render as grender
import gleamgen/types as gtypes
import gleamgen/types/custom as gcustom
import gleamgen/types/variant as gvariant

/// Renders a pragma migration Gleam module using gleamgen (imports, constants, types, functions).
pub fn build_and_render(data: PragmaMigrationData) -> String {
  let rendered =
    build(data)
    |> gmod.render(grender.default_context())
    |> grender.to_string()
  let with_header =
    string.concat([
      module_comment_block(data),
      "\n",
      sqlite_ident_import_prefix(rendered),
      rendered,
    ])
  case string.ends_with(with_header, "\n") {
    True -> with_header
    False -> string.append(with_header, "\n")
  }
}

/// One pragma migration module containing every entity in [datas] (sorted when built upstream).
pub fn build_and_render_multi(datas: List(PragmaMigrationData)) -> String {
  let rendered =
    build_multi(datas)
    |> gmod.render(grender.default_context())
    |> grender.to_string()
  let with_header =
    string.concat([
      module_comment_block_multi(datas),
      "\n",
      sqlite_ident_import_prefix(rendered),
      rendered,
    ])
  case string.ends_with(with_header, "\n") {
    True -> with_header
    False -> string.append(with_header, "\n")
  }
}

/// Gleamgen omits imports only referenced from `gexpr.raw` bodies; ALTER helpers use
/// `sqlite_ident.quote` in strings, so we inject this line when needed.
fn sqlite_ident_import_prefix(rendered: String) -> String {
  case
    string.contains(rendered, "sqlite_ident.quote("),
    string.contains(rendered, "import sql/sqlite_ident")
  {
    True, False -> "import sql/sqlite_ident as sqlite_ident\n\n"
    _, _ -> ""
  }
}

fn module_comment_block(data: PragmaMigrationData) -> String {
  string.join(
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
    ],
    "\n",
  )
}

fn module_comment_block_multi(datas: List(PragmaMigrationData)) -> String {
  let names =
    list.map(datas, fn(d) { d.table })
    |> list.sort(string.compare)
    |> string.join("`, `")
  string.join(
    [
      "//// Blueprint for a generated `migrate`: introspect user tables `"
        <> names
        <> "`",
      "//// columns / indexes, then move to the desired state using `ALTER TABLE` only",
      "//// (add / drop column), never `DROP TABLE` / `CREATE TABLE` for shape fixes once those tables exist.",
    ],
    "\n",
  )
}

fn build_multi(datas: List(PragmaMigrationData)) -> gmod.Module {
  case datas {
    [] -> panic as "pragma_migration_module.build_multi: empty entity list"
    [first, ..rest] ->
      with_all_imports(fn() {
        build_entity_multi(first, True, rest, fn() {
          with_migration_pub_multi(datas, fn() { gmod.eof() })
        })
      })
  }
}

fn build_entity_multi(
  data: PragmaMigrationData,
  is_first: Bool,
  rest: List(PragmaMigrationData),
  final_inner: fn() -> gmod.Module,
) -> gmod.Module {
  let after_this = case rest {
    [] -> final_inner
    [next, ..tail] -> fn() {
      build_entity_multi(next, False, tail, final_inner)
    }
  }
  let wrap_shared_helpers = fn(next_inner: fn() -> gmod.Module) {
    case is_first {
      True ->
        with_pragma_index(fn() { with_type_matches(fn() { next_inner() }) })
      False -> next_inner()
    }
  }
  with_string_constants(data, fn() {
    with_col_type_and_columns(data, fn() {
      wrap_shared_helpers(fn() {
        with_drop_surplus(data, fn() {
          with_row_matches(data, fn() {
            with_first_surplus(data, fn() {
              with_first_mismatched(data, fn() {
                with_first_missing(data, fn() {
                  with_alter_add(data, fn() {
                    with_apply_one(data, fn() {
                      with_reconcile_loop(data, fn() {
                        with_ensure_table(data, fn() {
                          with_ensure_indexes(data, after_this)
                        })
                      })
                    })
                  })
                })
              })
            })
          })
        })
      })
    })
  })
}

fn q(s: String) -> String {
  string.concat(["\"", s, "\""])
}

fn expected_table_info_const(data: PragmaMigrationData) -> String {
  case data.multi_entity {
    True -> string.concat(["expected_", data.table, "_table_info"])
    False -> "expected_table_info"
  }
}

fn expected_index_list_const(data: PragmaMigrationData) -> String {
  case data.multi_entity {
    True -> string.concat(["expected_", data.table, "_index_list"])
    False -> "expected_index_list"
  }
}

fn expected_index_info_const(data: PragmaMigrationData) -> String {
  case data.multi_entity {
    True -> string.concat(["expected_", data.table, "_index_info"])
    False -> "expected_index_info"
  }
}

fn first_surplus_column_fn(data: PragmaMigrationData) -> String {
  case data.multi_entity {
    True -> string.concat(["first_surplus_column_", data.table])
    False -> "first_surplus_column"
  }
}

fn first_mismatched_column_name_fn(data: PragmaMigrationData) -> String {
  case data.multi_entity {
    True -> string.concat(["first_mismatched_column_name_", data.table])
    False -> "first_mismatched_column_name"
  }
}

fn first_missing_column_fn(data: PragmaMigrationData) -> String {
  case data.multi_entity {
    True -> string.concat(["first_missing_column_", data.table])
    False -> "first_missing_column"
  }
}

fn wanted_list(data: PragmaMigrationData) -> String {
  string.concat([data.table, "_columns_wanted"])
}

fn conn_tuple_table(data: PragmaMigrationData) -> String {
  string.concat(["(conn, ", q(data.table), ")"])
}

fn conn_tuple_index(data: PragmaMigrationData) -> String {
  string.concat(["(conn, ", q(data.index_name), ")"])
}

fn build(data: PragmaMigrationData) -> gmod.Module {
  with_all_imports(fn() {
    with_string_constants(data, fn() {
      with_col_type_and_columns(data, fn() {
        with_pragma_index(fn() {
          with_drop_surplus(data, fn() {
            with_type_matches(fn() {
              with_row_matches(data, fn() {
                with_first_surplus(data, fn() {
                  with_first_mismatched(data, fn() {
                    with_first_missing(data, fn() {
                      with_alter_add(data, fn() {
                        with_apply_one(data, fn() {
                          with_reconcile_loop(data, fn() {
                            with_ensure_table(data, fn() {
                              with_ensure_indexes(data, fn() {
                                with_migration_pub(data, fn() { gmod.eof() })
                              })
                            })
                          })
                        })
                      })
                    })
                  })
                })
              })
            })
          })
        })
      })
    })
  })
}

fn with_all_imports(inner: fn() -> gmod.Module) -> gmod.Module {
  // Only referenced from `gexpr.raw` strings; gleamgen skips normal imports otherwise.
  gmod.with_import(
    gimport.new_predefined(["gleam", "dynamic", "decode"]),
    fn(_d) {
      gmod.with_import(gimport.new_predefined(["gleam", "list"]), fn(_l) {
        gmod.with_import(
          gimport.new_with_exposing(
            ["gleam", "option"],
            "type Option, None, Some",
          ),
          fn(_o) {
            gmod.with_import(
              gimport.new_predefined(["gleam", "result"]),
              fn(_r) {
                gmod.with_import(gimport.new(["gleam", "string"]), fn(_s) {
                  gmod.with_import(gimport.new(["sqlight"]), fn(_sql) {
                    gmod.with_import(
                      gimport.new_with_alias_and_exposing(
                        ["sql", "pragma_assert"],
                        "sqlite_pragma_assert",
                        "type TableInfoRow",
                      ),
                      fn(_p) { inner() },
                    )
                  })
                })
              },
            )
          },
        )
      })
    },
  )
}

fn def_const(
  name: String,
  value: gexpr.Expression(String),
  next: fn() -> gmod.Module,
) {
  gmod.with_constant(gdef.new(name), value, fn(_) { next() })
}

fn with_string_constants(data: PragmaMigrationData, next: fn() -> gmod.Module) {
  let exp_table = expected_table_info_const(data)
  let exp_list = expected_index_list_const(data)
  let exp_info = expected_index_info_const(data)
  def_const(
    string.concat(["create_", data.table, "_table_sql"]),
    gexpr.string(data.create_table_sql),
    fn() {
      def_const(
        string.concat([
          "create_",
          data.table,
          "_by_",
          data.index_suffix,
          "_index_sql",
        ]),
        gexpr.string(data.create_index_sql),
        fn() {
          def_const(exp_table, gexpr.string(data.expected_table_info), fn() {
            def_const(exp_list, gexpr.string(data.expected_index_list), fn() {
              def_const(exp_info, gexpr.string(data.expected_index_info), fn() {
                next()
              })
            })
          })
        },
      )
    },
  )
}

fn columns_wanted_list_expr(
  col_con: gconstructor.Constructor(c, d, e),
  data: PragmaMigrationData,
) -> gexpr.Expression(List(gtypes.Dynamic)) {
  data.wanted_rows
  |> list.map(fn(row) {
    let #(n, t, nn, pk) = row
    gexpr.call_dynamic(gconstructor.to_expression_dynamic(col_con), [
      gexpr.to_dynamic(gexpr.string(n)),
      gexpr.to_dynamic(gexpr.string(t)),
      gexpr.to_dynamic(gexpr.int(nn)),
      gexpr.to_dynamic(gexpr.int(pk)),
    ])
  })
  |> gexpr.list
}

fn with_col_type_and_columns(
  data: PragmaMigrationData,
  next: fn() -> gmod.Module,
) -> gmod.Module {
  gmod.with_custom_type1(
    gdef.new(data.col_type),
    gcustom.new(#())
      |> gcustom.with_variant(fn(_g) {
        gvariant.new(data.col_type)
        |> gvariant.with_argument(option.Some("name"), gtypes.string)
        |> gvariant.with_argument(option.Some("type_"), gtypes.string)
        |> gvariant.with_argument(option.Some("notnull"), gtypes.int)
        |> gvariant.with_argument(option.Some("pk"), gtypes.int)
      }),
    fn(_ct, col_con) {
      let cols = columns_wanted_list_expr(col_con, data)
      gmod.with_constant(
        gdef.new(string.concat([data.table, "_columns_wanted"])),
        cols,
        fn(_) { next() },
      )
    },
  )
}

fn raw_fn1(body: String, p1: gparam.Parameter(p1), ret: gtypes.GeneratedType(a)) {
  gfun.new1(p1, ret, fn(_a) { gexpr.raw(body) })
}

fn raw_fn2(
  body: String,
  p1: gparam.Parameter(p1),
  p2: gparam.Parameter(p2),
  ret: gtypes.GeneratedType(a),
) {
  gfun.new2(p1, p2, ret, fn(_a, _b) { gexpr.raw(body) })
}

fn with_fn(
  name: String,
  func: gfun.Function(f, r),
  next: fn() -> gmod.Module,
  public public: Bool,
) -> gmod.Module {
  let d = gdef.new(name)
  let d = case public {
    True -> gdef.with_publicity(d, True)
    False -> d
  }
  gmod.with_function(d, func, fn(_) { next() })
}

fn with_pragma_index(next: fn() -> gmod.Module) -> gmod.Module {
  let body =
    string.join(
      [
        "sqlight.query(",
        "  \"pragma index_list(\" <> table <> \")\",",
        "  on: conn,",
        "  with: [],",
        "  expecting: {",
        "    use name <- decode.field(1, decode.string)",
        "    use origin <- decode.field(3, decode.string)",
        "    decode.success(#(name, origin))",
        "  },",
        ")",
      ],
      "\n",
    )
  with_fn(
    "pragma_index_name_origin_rows",
    raw_fn2(
      body,
      gparam.new("conn", gtypes.raw("sqlight.Connection")),
      gparam.new("table", gtypes.string),
      gtypes.raw("Result(List(#(String, String)), sqlight.Error)"),
    ),
    next,
    public: False,
  )
}

fn with_drop_surplus(data: PragmaMigrationData, next: fn() -> gmod.Module) {
  let conn_t = conn_tuple_table(data)
  let body =
    string.join(
      [
        string.concat([
          "use rows <- result.try(pragma_index_name_origin_rows",
          conn_t,
          ")",
        ]),
        "list.try_each(rows, fn(pair) {",
        "  let #(name, origin) = pair",
        string.concat([
          "  case origin == ",
          q("c"),
          " && name != ",
          q(data.index_name),
          " {",
        ]),
        "    True -> sqlight.exec(\"drop index if exists \" <> name <> \";\", conn)",
        "    False -> Ok(Nil)",
        "  }",
        "})",
      ],
      "\n",
    )
  with_fn(
    string.concat(["drop_surplus_user_indexes_on_", data.table]),
    raw_fn1(
      body,
      gparam.new("conn", gtypes.raw("sqlight.Connection")),
      gtypes.raw("Result(Nil, sqlight.Error)"),
    ),
    next,
    public: False,
  )
}

fn with_type_matches(next: fn() -> gmod.Module) -> gmod.Module {
  let body = "string.uppercase(got) == expected"
  with_fn(
    "type_matches",
    raw_fn2(
      body,
      gparam.new("expected", gtypes.string),
      gparam.new("got", gtypes.string),
      gtypes.bool,
    ),
    next,
    public: False,
  )
}

fn with_row_matches(data: PragmaMigrationData, next: fn() -> gmod.Module) {
  let body =
    string.join(
      [
        "want.name == got.name",
        "&& type_matches(want.type_, got.type_)",
        "&& want.notnull == got.notnull",
        "&& want.pk == got.pk",
        "&& case want.notnull {",
        "  0 -> got.dflt == None || got.dflt == Some(\"\")",
        "  _ -> True",
        "}",
      ],
      "\n",
    )
  with_fn(
    string.concat([data.table, "_row_matches"]),
    raw_fn2(
      body,
      gparam.new("want", gtypes.raw(data.col_type)),
      gparam.new("got", gtypes.raw("TableInfoRow")),
      gtypes.bool,
    ),
    next,
    public: False,
  )
}

fn with_first_surplus(data: PragmaMigrationData, next: fn() -> gmod.Module) {
  let body =
    string.join(
      [
        "case",
        "  list.find(rows, fn(r) { !list.any(wanted, fn(w) { w.name == r.name }) })",
        "{",
        "  Ok(r) -> Some(r.name)",
        "  Error(Nil) -> None",
        "}",
      ],
      "\n",
    )
  with_fn(
    first_surplus_column_fn(data),
    raw_fn2(
      body,
      gparam.new("rows", gtypes.raw("List(TableInfoRow)")),
      gparam.new(
        "wanted",
        gtypes.raw(string.concat(["List(", data.col_type, ")"])),
      ),
      gtypes.raw("Option(String)"),
    ),
    next,
    public: False,
  )
}

fn with_first_mismatched(data: PragmaMigrationData, next: fn() -> gmod.Module) {
  let row_match = string.concat([data.table, "_row_matches"])
  let body =
    string.join(
      [
        "case",
        "  list.find_map(wanted, fn(w) {",
        "    case list.find(rows, fn(r) { r.name == w.name }) {",
        "      Error(Nil) -> Error(Nil)",
        "      Ok(row) ->",
        string.concat(["        case ", row_match, "(w, row) {"]),
        "          True -> Error(Nil)",
        "          False -> Ok(w.name)",
        "        }",
        "    }",
        "  })",
        "{",
        "  Ok(name) -> Some(name)",
        "  Error(Nil) -> None",
        "}",
      ],
      "\n",
    )
  with_fn(
    first_mismatched_column_name_fn(data),
    raw_fn2(
      body,
      gparam.new("rows", gtypes.raw("List(TableInfoRow)")),
      gparam.new(
        "wanted",
        gtypes.raw(string.concat(["List(", data.col_type, ")"])),
      ),
      gtypes.raw("Option(String)"),
    ),
    next,
    public: False,
  )
}

fn with_first_missing(data: PragmaMigrationData, next: fn() -> gmod.Module) {
  let body =
    string.join(
      [
        "case",
        "  list.find(wanted, fn(w) { !list.any(rows, fn(r) { r.name == w.name }) })",
        "{",
        "  Ok(w) -> Some(w)",
        "  Error(Nil) -> None",
        "}",
      ],
      "\n",
    )
  with_fn(
    first_missing_column_fn(data),
    raw_fn2(
      body,
      gparam.new("rows", gtypes.raw("List(TableInfoRow)")),
      gparam.new(
        "wanted",
        gtypes.raw(string.concat(["List(", data.col_type, ")"])),
      ),
      gtypes.raw(string.concat(["Option(", data.col_type, ")"])),
    ),
    next,
    public: False,
  )
}

fn with_alter_add(data: PragmaMigrationData, next: fn() -> gmod.Module) {
  let body =
    string.join(
      [
        "let fragment = case w.name {",
        "  \"id\" -> \"integer primary key autoincrement not null\"",
        "  \"deleted_at\" -> \"integer\"",
        "  _ ->",
        "    case string.uppercase(w.type_) {",
        "      \"INTEGER\" -> \"integer\"",
        "      \"TEXT\" -> \"text\"",
        "      \"REAL\" -> \"real\"",
        "      _ -> \"text\"",
        "    }",
        "    <> case w.notnull {",
        "      1 -> \" not null\"",
        "      _ -> \"\"",
        "    }",
        "}",
        string.concat([
          "\"alter table \" <> sqlite_ident.quote(\"",
          data.table,
          "\") <> \" add column \" <> sqlite_ident.quote(w.name) <> \" \" <> fragment <> \";\"",
        ]),
      ],
      "\n",
    )
  with_fn(
    string.concat(["alter_add_", data.table, "_column_sql"]),
    raw_fn1(body, gparam.new("w", gtypes.raw(data.col_type)), gtypes.string),
    next,
    public: False,
  )
}

fn apply_one_body_lines(data: PragmaMigrationData) -> List(String) {
  let wl = wanted_list(data)
  let alter_fn = string.concat(["alter_add_", data.table, "_column_sql"])
  let fs = first_surplus_column_fn(data)
  let fm = first_mismatched_column_name_fn(data)
  let fmi = first_missing_column_fn(data)
  let none_panic_lines = string.split(data.apply_one_none_panic, "\n")
  list.flatten([
    [
      string.concat(["case ", fs, "(rows, ", wl, ") {"]),
      "  Some(name) ->",
      string.concat([
        "    sqlight.exec(\"alter table \" <> sqlite_ident.quote(\"",
        data.table,
        "\") <> \" drop column \" <> sqlite_ident.quote(name) <> \";\", conn)",
      ]),
      "  None ->",
      string.concat(["    case ", fm, "(rows, ", wl, ") {"]),
      "      Some(name) ->",
      string.concat([
        "        sqlight.exec(\"alter table \" <> sqlite_ident.quote(\"",
        data.table,
        "\") <> \" drop column \" <> sqlite_ident.quote(name) <> \";\", conn)",
      ]),
      "      None ->",
      string.concat(["        case ", fmi, "(rows, ", wl, ") {"]),
      string.concat([
        "          Some(w) -> sqlight.exec(",
        alter_fn,
        "(w), conn)",
      ]),
    ],
    none_panic_lines,
    ["        }", "    }", "}"],
  ])
}

fn with_apply_one(
  data: PragmaMigrationData,
  next: fn() -> gmod.Module,
) -> gmod.Module {
  let body = string.join(apply_one_body_lines(data), "\n")
  with_fn(
    string.concat(["apply_one_", data.table, "_column_fix"]),
    raw_fn2(
      body,
      gparam.new("conn", gtypes.raw("sqlight.Connection")),
      gparam.new("rows", gtypes.raw("List(TableInfoRow)")),
      gtypes.raw("Result(Nil, sqlight.Error)"),
    ),
    next,
    public: False,
  )
}

fn reconcile_body_string(data: PragmaMigrationData) -> String {
  let wl = wanted_list(data)
  let row_match = string.concat([data.table, "_row_matches"])
  let apply_fn = string.concat(["apply_one_", data.table, "_column_fix"])
  let loop_fn = string.concat(["reconcile_", data.table, "_columns_loop"])
  let reconcile_lines = string.split(data.reconcile_table_info_rows_stmt, "\n")
  list.flatten([
    [
      "case iter > 64 {",
      "  True ->",
      string.concat(["    panic as ", data.panic_no_conv]),
      "  False -> {",
    ],
    reconcile_lines,
    [
      "    case",
      string.concat([
        "      list.length(rows) == list.length(",
        wl,
        ")",
      ]),
      string.concat(["      && list.all(", wl, ", fn(w) {"]),
      "        case list.find(rows, fn(r) { r.name == w.name }) {",
      string.concat(["          Ok(row) -> ", row_match, "(w, row)"]),
      "          Error(Nil) -> False",
      "        }",
      "      })",
      "    {",
      "      True -> Ok(Nil)",
      "      False -> {",
      string.concat([
        "        use _ <- result.try(",
        apply_fn,
        "(conn, rows))",
      ]),
      string.concat(["        ", loop_fn, "(conn, iter + 1)"]),
      "      }",
      "    }",
      "  }",
      "}",
    ],
  ])
  |> string.join("\n")
}

fn with_reconcile_loop(
  data: PragmaMigrationData,
  next: fn() -> gmod.Module,
) -> gmod.Module {
  let body = reconcile_body_string(data)
  with_fn(
    string.concat(["reconcile_", data.table, "_columns_loop"]),
    raw_fn2(
      body,
      gparam.new("conn", gtypes.raw("sqlight.Connection")),
      gparam.new("iter", gtypes.int),
      gtypes.raw("Result(Nil, sqlight.Error)"),
    ),
    next,
    public: False,
  )
}

fn with_ensure_table(
  data: PragmaMigrationData,
  next: fn() -> gmod.Module,
) -> gmod.Module {
  let loop_fn = string.concat(["reconcile_", data.table, "_columns_loop"])
  let body =
    string.join(
      [
        "use tables <- result.try(sqlite_pragma_assert.user_table_names(conn))",
        string.concat(["case list.contains(tables, ", q(data.table), ") {"]),
        string.concat([
          "  False -> sqlight.exec(create_",
          data.table,
          "_table_sql, conn)",
        ]),
        string.concat(["  True -> ", loop_fn, "(conn, 0)"]),
        "}",
      ],
      "\n",
    )
  with_fn(
    string.concat(["ensure_", data.table, "_table"]),
    raw_fn1(
      body,
      gparam.new("conn", gtypes.raw("sqlight.Connection")),
      gtypes.raw("Result(Nil, sqlight.Error)"),
    ),
    next,
    public: False,
  )
}

fn with_ensure_indexes(
  data: PragmaMigrationData,
  next: fn() -> gmod.Module,
) -> gmod.Module {
  let conn_t = conn_tuple_table(data)
  let conn_index = conn_tuple_index(data)
  let exp_list = expected_index_list_const(data)
  let exp_info = expected_index_info_const(data)
  let create_idx =
    string.concat([
      "create_",
      data.table,
      "_by_",
      data.index_suffix,
      "_index_sql",
    ])
  let drop_surplus_fn =
    string.concat(["drop_surplus_user_indexes_on_", data.table])
  let body =
    string.join(
      [
        string.concat([
          "use _ <- result.try(",
          drop_surplus_fn,
          "(conn))",
        ]),
        "case",
        string.concat([
          "  sqlite_pragma_assert.index_list_tsv",
          conn_t,
          ",",
        ]),
        string.concat([
          "  sqlite_pragma_assert.index_info_tsv",
          conn_index,
        ]),
        "{",
        "  Ok(list_tsv), Ok(info_tsv) ->",
        string.concat([
          "    case list_tsv == ",
          exp_list,
          " && info_tsv == ",
          exp_info,
          " {",
        ]),
        "      True -> Ok(Nil)",
        "      False -> {",
        "        use _ <- result.try(sqlight.exec(",
        string.concat([
          "          \"drop index if exists ",
          data.index_name,
          ";\",",
        ]),
        "          conn,",
        "        ))",
        string.concat(["        sqlight.exec(", create_idx, ", conn)"]),
        "      }",
        "    }",
        "  _, _ -> {",
        "    use _ <- result.try(sqlight.exec(",
        string.concat([
          "      \"drop index if exists ",
          data.index_name,
          ";\",",
        ]),
        "      conn,",
        "    ))",
        string.concat(["    sqlight.exec(", create_idx, ", conn)"]),
        "  }",
        "}",
      ],
      "\n",
    )
  with_fn(
    string.concat(["ensure_", data.table, "_indexes"]),
    raw_fn1(
      body,
      gparam.new("conn", gtypes.raw("sqlight.Connection")),
      gtypes.raw("Result(Nil, sqlight.Error)"),
    ),
    next,
    public: False,
  )
}

fn migration_multi_body_string(datas: List(PragmaMigrationData)) -> String {
  let tables_sorted =
    list.map(datas, fn(d) { d.table })
    |> list.sort(string.compare)
  let keep_list = list.map(tables_sorted, q) |> string.join(", ")
  let drop_block =
    string.join(
      [
        "use _ <- result.try(sqlite_pragma_assert.drop_user_tables_except_any(",
        "  conn,",
        "  [" <> keep_list <> "],",
        "))",
      ],
      "\n",
    )
  let ensure_each =
    list.map(datas, fn(d) {
      let t = d.table
      string.join(
        [
          "use _ <- result.try(ensure_" <> t <> "_table(conn))",
          "use _ <- result.try(ensure_" <> t <> "_indexes(conn))",
        ],
        "\n",
      )
    })
    |> string.join("\n")
  let snap_each =
    list.map(datas, fn(d) {
      let ti = expected_table_info_const(d)
      let il = expected_index_list_const(d)
      let ii = expected_index_info_const(d)
      string.join(
        [
          "sqlite_pragma_assert.assert_pragma_snapshot(",
          "  conn,",
          "  [" <> keep_list <> "],",
          "  " <> q(d.table) <> ",",
          "  " <> ti <> ",",
          "  " <> il <> ",",
          "  " <> q(d.index_name) <> ",",
          "  " <> ii <> ",",
          ")",
        ],
        "\n",
      )
    })
    |> string.join("\n")
  string.join([drop_block, ensure_each, snap_each, "Ok(Nil)"], "\n")
}

fn with_migration_pub_multi(
  datas: List(PragmaMigrationData),
  next: fn() -> gmod.Module,
) -> gmod.Module {
  let body = migration_multi_body_string(datas)
  with_fn(
    "migration",
    raw_fn1(
      body,
      gparam.new("conn", gtypes.raw("sqlight.Connection")),
      gtypes.raw("Result(Nil, sqlight.Error)"),
    ),
    next,
    public: True,
  )
}

fn with_migration_pub(
  data: PragmaMigrationData,
  next: fn() -> gmod.Module,
) -> gmod.Module {
  let ensure_t = string.concat(["ensure_", data.table, "_table"])
  let ensure_i = string.concat(["ensure_", data.table, "_indexes"])
  let body =
    string.join(
      [
        "use _ <- result.try(sqlite_pragma_assert.drop_user_tables_except(",
        "  conn,",
        string.concat(["  ", q(data.table), ","]),
        "))",
        string.concat(["use _ <- result.try(", ensure_t, "(conn))"]),
        string.concat(["use _ <- result.try(", ensure_i, "(conn))"]),
        "sqlite_pragma_assert.assert_pragma_snapshot(",
        "  conn,",
        string.concat(["  [", q(data.table), "],"]),
        string.concat(["  ", q(data.table), ","]),
        "  expected_table_info,",
        "  expected_index_list,",
        string.concat(["  ", q(data.index_name), ","]),
        "  expected_index_info,",
        ")",
        "Ok(Nil)",
      ],
      "\n",
    )
  with_fn(
    "migration",
    raw_fn1(
      body,
      gparam.new("conn", gtypes.raw("sqlight.Connection")),
      gtypes.raw("Result(Nil, sqlight.Error)"),
    ),
    next,
    public: True,
  )
}
