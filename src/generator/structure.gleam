import glance
import gleam/list
import gleam/option
import gleam/string

import generator/gleamgen_emit
import generator/schema_context.{type SchemaContext, pascal_case_field_label}
import generator/sql_types

import gleamgen/expression as gex
import gleamgen/expression/block as gblock
import gleamgen/function as gfun
import gleamgen/import_ as gim
import gleamgen/module as gmod
import gleamgen/types as gtypes
import gleamgen/types/custom as gcustom
import gleamgen/types/variant as gvariant

pub fn generate(ctx: SchemaContext) -> String {
  let layer = ctx.layer
  let schema_mod = ctx.schema_module
  let t = ctx.type_name
  let v = ctx.variant_name
  let fl = ctx.filterable_name
  let row = ctx.row_name
  let db = ctx.db_type_name
  let fe = ctx.field_enum_name
  let ne = ctx.num_field_enum_name
  let se = ctx.string_field_enum_name
  let upsert = ctx.for_upsert_type_name
  let singular = ctx.singular

  let decode_mod = gim.new(["gleam", "dynamic", "decode"])
  let option_mod =
    gim.new_with_exposing(["gleam", "option"], "type Option")
  let resource_mod =
    gim.new_with_exposing([layer, "resource"], "type " <> upsert)
  let schema_import =
    gim.new_with_exposing([schema_mod], "type " <> t <> ", " <> v)
  let filter_mod = gim.new_predefined(["help", "filter"])
  let sqlight_mod = gim.new_predefined(["sqlight"])

  let filterable_builder = filterable_custom(ctx, fl)
  let string_ref_builder = string_ref_or_value_custom(se)
  let num_ref_builder = num_ref_or_value_custom(ne)
  let num_enum_builder = num_field_enum_custom(ctx, ne)
  let string_enum_builder = string_field_enum_custom(ctx, se)
  let field_enum_builder = full_field_enum_custom(ctx, fe)
  let row_builder = row_custom(ctx, row, t)
  let db_builder = db_custom(ctx, db, upsert, t, row, fl, fe)

  let decoder_fn = singular <> "_row_decoder"
  let decoder_body = row_decoder_expression(ctx, row, v)
  let decoder_ret = gtypes.raw("decode.Decoder(" <> row <> ")")
  let decoder =
    gfun.new0(returns: decoder_ret, handler: fn() { decoder_body })

  gleamgen_emit.render_module(
    gmod.with_import(decode_mod, fn(_) {
      gmod.with_import(option_mod, fn(_) {
        gmod.with_import(resource_mod, fn(_) {
          gmod.with_import(schema_import, fn(_) {
            gmod.with_import(filter_mod, fn(_) {
              gmod.with_import(sqlight_mod, fn(_) {
                gmod.with_custom_type_dynamic(
                  gleamgen_emit.pub_def(fl),
                  filterable_builder,
                  fn(_, _) {
                    gmod.with_custom_type_dynamic(
                      gleamgen_emit.pub_def("StringRefOrValue"),
                      string_ref_builder,
                      fn(_, _) {
                        gmod.with_custom_type_dynamic(
                          gleamgen_emit.pub_def("NumRefOrValue"),
                          num_ref_builder,
                          fn(_, _) {
                            gmod.with_custom_type_dynamic(
                              gleamgen_emit.pub_def(ne),
                              num_enum_builder,
                              fn(_, _) {
                                gmod.with_custom_type_dynamic(
                                  gleamgen_emit.pub_def(se),
                                  string_enum_builder,
                                  fn(_, _) {
                                    gmod.with_custom_type_dynamic(
                                      gleamgen_emit.pub_def(fe),
                                      field_enum_builder,
                                      fn(_, _) {
                                        gmod.with_custom_type_dynamic(
                                          gleamgen_emit.pub_def(row),
                                          row_builder,
                                          fn(_, _) {
                                            gmod.with_custom_type_dynamic(
                                              gleamgen_emit.pub_def(db),
                                              db_builder,
                                              fn(_, _) {
                                                gmod.with_function(
                                                  gleamgen_emit.pub_def(
                                                    decoder_fn,
                                                  ),
                                                  decoder,
                                                  fn(_) { gmod.eof() },
                                                )
                                              },
                                            )
                                          },
                                        )
                                      },
                                    )
                                  },
                                )
                              },
                            )
                          },
                        )
                      },
                    )
                  },
                )
              })
            })
          })
        })
      })
    }),
  )
  |> format_structure_module
}

fn format_structure_module(src: String) -> String {
  let src = reorder_structure_import_block(src)
  src
  |> string.replace(
    each: "    update_many:\n    fn(",
    with: "    update_many: fn(",
  )
  |> string.replace(
    each: "    read_many:\n    fn(",
    with: "    read_many: fn(",
  )
}

fn reorder_structure_import_block(src: String) -> String {
  case string.split_once(src, "\n\npub ") {
    Error(_) -> src
    Ok(#(before, after)) -> {
      let lines =
        string.split(before, "\n")
        |> list.filter(fn(line) {
          let t = string.trim(line)
          t != "" && string.starts_with(t, "import ")
        })
      let gleam =
        list.filter(lines, fn(line) {
          string.starts_with(string.trim(line), "import gleam")
        })
      let other =
        list.filter(lines, fn(line) {
          !string.starts_with(string.trim(line), "import gleam")
        })
      let gleam_sorted = list.sort(gleam, string.compare)
      let other_sorted = list.sort(other, string.compare)
      let import_block = case gleam_sorted, other_sorted {
        [], _ -> string.join(other_sorted, "\n")
        _, [] -> string.join(gleam_sorted, "\n")
        _, _ ->
          string.join(gleam_sorted, "\n") <> "\n\n" <> string.join(other_sorted, "\n")
      }
      import_block <> "\n\npub " <> after
    }
  }
}

fn filterable_custom(ctx: SchemaContext, fl: String) {
  let schema_args =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      let ref = case sql_types.filter_is_string_column(typ) {
        True -> "StringRefOrValue"
        False -> "NumRefOrValue"
      }
      #(option.Some(label), gtypes.raw(ref) |> gtypes.to_dynamic)
    })
  let tail = [
    #(option.Some("id"), gtypes.raw("NumRefOrValue") |> gtypes.to_dynamic),
    #(
      option.Some("created_at"),
      gtypes.raw("NumRefOrValue") |> gtypes.to_dynamic,
    ),
    #(
      option.Some("updated_at"),
      gtypes.raw("NumRefOrValue") |> gtypes.to_dynamic,
    ),
    #(
      option.Some("deleted_at"),
      gtypes.raw("NumRefOrValue") |> gtypes.to_dynamic,
    ),
  ]
  let args = list.append(schema_args, tail)
  gcustom.new(Nil)
  |> gcustom.with_dynamic_variants(fn(_) {
    [
      gvariant.with_arguments_dynamic(gvariant.new(fl), args)
        |> gvariant.to_dynamic,
    ]
  })
}

fn string_ref_or_value_custom(se: String) {
  gcustom.new(Nil)
  |> gcustom.with_dynamic_variants(fn(_) {
    [
      gvariant.with_arguments_dynamic(gvariant.new("StringRef"), [
        #(option.Some("ref"), gtypes.raw(se) |> gtypes.to_dynamic),
      ])
        |> gvariant.to_dynamic,
      gvariant.with_arguments_dynamic(gvariant.new("StrVal"), [
        #(option.Some("value"), gtypes.string |> gtypes.to_dynamic),
      ])
        |> gvariant.to_dynamic,
    ]
  })
}

fn num_ref_or_value_custom(ne: String) {
  gcustom.new(Nil)
  |> gcustom.with_dynamic_variants(fn(_) {
    [
      gvariant.with_arguments_dynamic(gvariant.new("NumRef"), [
        #(option.Some("ref"), gtypes.raw(ne) |> gtypes.to_dynamic),
      ])
        |> gvariant.to_dynamic,
      gvariant.with_arguments_dynamic(gvariant.new("IntVal"), [
        #(option.Some("value"), gtypes.int |> gtypes.to_dynamic),
      ])
        |> gvariant.to_dynamic,
      gvariant.with_arguments_dynamic(gvariant.new("FloatVal"), [
        #(option.Some("value"), gtypes.float |> gtypes.to_dynamic),
      ])
        |> gvariant.to_dynamic,
    ]
  })
}

fn num_field_enum_custom(ctx: SchemaContext, _ne: String) {
  let schema_variants =
    list.map(numeric_schema_fields(ctx), fn(pair) {
      gvariant.new(pascal_case_field_label(pair.0) <> "Int")
      |> gvariant.to_dynamic
    })
  let system = [
    gvariant.new("IdInt") |> gvariant.to_dynamic,
    gvariant.new("CreatedAtInt") |> gvariant.to_dynamic,
    gvariant.new("UpdatedAtInt") |> gvariant.to_dynamic,
    gvariant.new("DeletedAtInt") |> gvariant.to_dynamic,
  ]
  gcustom.new(Nil)
  |> gcustom.with_dynamic_variants(fn(_) {
    list.append(schema_variants, system)
  })
}

fn string_field_enum_custom(ctx: SchemaContext, _se: String) {
  let variants =
    list.map(string_schema_fields(ctx), fn(pair) {
      gvariant.new(pascal_case_field_label(pair.0) <> "String")
      |> gvariant.to_dynamic
    })
  gcustom.new(Nil)
  |> gcustom.with_dynamic_variants(fn(_) { variants })
}

fn full_field_enum_custom(ctx: SchemaContext, _fe: String) {
  let schema_variants =
    list.map(ctx.fields, fn(pair) {
      gvariant.new(pascal_case_field_label(pair.0) <> "Field")
      |> gvariant.to_dynamic
    })
  let system = [
    gvariant.new("IdField") |> gvariant.to_dynamic,
    gvariant.new("CreatedAtField") |> gvariant.to_dynamic,
    gvariant.new("UpdatedAtField") |> gvariant.to_dynamic,
    gvariant.new("DeletedAtField") |> gvariant.to_dynamic,
  ]
  gcustom.new(Nil)
  |> gcustom.with_dynamic_variants(fn(_) {
    list.append(schema_variants, system)
  })
}

fn row_custom(_ctx: SchemaContext, row: String, t: String) {
  let deleted =
    gtypes.custom_type(option.None, "Option", [gtypes.int |> gtypes.to_dynamic])
  let args = [
    #(option.Some("value"), gtypes.raw(t) |> gtypes.to_dynamic),
    #(option.Some("id"), gtypes.int |> gtypes.to_dynamic),
    #(option.Some("created_at"), gtypes.int |> gtypes.to_dynamic),
    #(option.Some("updated_at"), gtypes.int |> gtypes.to_dynamic),
    #(option.Some("deleted_at"), deleted |> gtypes.to_dynamic),
  ]
  gcustom.new(Nil)
  |> gcustom.with_dynamic_variants(fn(_) {
    [
      gvariant.with_arguments_dynamic(gvariant.new(row), args)
        |> gvariant.to_dynamic,
    ]
  })
}

fn db_custom(
  _ctx: SchemaContext,
  db: String,
  upsert: String,
  t: String,
  row: String,
  fl: String,
  fe: String,
) {
  let sqlight_error =
    gtypes.custom_type(option.Some("sqlight"), "Error", [])
  let row_t = gtypes.raw(row)
  let schema_t = gtypes.raw(t)
  let upsert_t = gtypes.raw(upsert)
  let opt_row =
    gtypes.custom_type(option.None, "Option", [row_t |> gtypes.to_dynamic])
  let filter_arg =
    gtypes.custom_type(option.Some("filter"), "FilterArg", [
      gtypes.raw(fl) |> gtypes.to_dynamic,
      gtypes.raw("NumRefOrValue") |> gtypes.to_dynamic,
      gtypes.raw("StringRefOrValue") |> gtypes.to_dynamic,
      gtypes.raw(fe) |> gtypes.to_dynamic,
    ])
  let result_nil = gtypes.result(gtypes.nil, sqlight_error)
  let result_row = gtypes.result(row_t, sqlight_error)
  let result_list_row = gtypes.result(gtypes.list(row_t), sqlight_error)
  let result_opt_row = gtypes.result(opt_row, sqlight_error)
  let result_list_opt_row =
    gtypes.result(gtypes.list(opt_row), sqlight_error)

  let args = [
    #(
      option.Some("migrate"),
      gtypes.function0(result_nil) |> gtypes.to_dynamic,
    ),
    #(
      option.Some("upsert_one"),
      gtypes.function1(upsert_t, result_row) |> gtypes.to_dynamic,
    ),
    #(
      option.Some("upsert_many"),
      gtypes.function1(gtypes.list(upsert_t), result_list_row)
        |> gtypes.to_dynamic,
    ),
    #(
      option.Some("update_one"),
      gtypes.function2(gtypes.int, schema_t, result_opt_row)
        |> gtypes.to_dynamic,
    ),
    #(
      option.Some("update_many"),
      gtypes.function1(
        gtypes.list(gtypes.tuple2(gtypes.int, schema_t)),
        result_list_opt_row,
      )
        |> gtypes.to_dynamic,
    ),
    #(
      option.Some("read_one"),
      gtypes.function1(gtypes.int, result_opt_row) |> gtypes.to_dynamic,
    ),
    #(
      option.Some("read_many"),
      gtypes.function1(filter_arg, result_list_row) |> gtypes.to_dynamic,
    ),
    #(
      option.Some("delete_one"),
      gtypes.function1(gtypes.int, result_nil) |> gtypes.to_dynamic,
    ),
    #(
      option.Some("delete_many"),
      gtypes.function1(gtypes.list(gtypes.int), result_nil)
        |> gtypes.to_dynamic,
    ),
  ]
  gcustom.new(Nil)
  |> gcustom.with_dynamic_variants(fn(_) {
    [
      gvariant.with_arguments_dynamic(gvariant.new(db), args)
        |> gvariant.to_dynamic,
    ]
  })
}

fn row_decoder_expression(
  ctx: SchemaContext,
  row: String,
  v: String,
) -> gex.Expression(a) {
  let system = [
    #("id", 0, "decode.int"),
    #("created_at", 1, "decode.int"),
    #("updated_at", 2, "decode.int"),
    #("deleted_at", 3, "decode.optional(decode.int)"),
  ]
  let schema_steps =
    list.map(ctx.fields, fn(pair) {
      let #(label, typ) = pair
      #(
        label,
        4 + field_index(ctx.fields, label),
        sql_types.decode_expression(typ),
      )
    })
  let steps = list.append(system, schema_steps)
  let success =
    gex.raw(
      "decode.success("
      <> row
      <> "(\n    value: "
      <> v
      <> "("
      <> join_label_value_pairs(ctx.fields)
      <> "),\n    id:,\n    created_at:,\n    updated_at:,\n    deleted_at:,\n  ))",
    )
  list.fold(list.reverse(steps), success, fn(inner, step) {
    let #(name, idx, dec_src) = step
    let uf =
      gblock.use_function2(
        gex.raw("decode.field"),
        gex.int(idx),
        gex.raw(dec_src),
      )
    gblock.with_use1(uf, name, fn(_) { inner })
  })
}

fn join_label_value_pairs(fields: List(#(String, a))) -> String {
  case fields {
    [] -> ""
    [#(l, _), ..rest] ->
      l
      <> ": "
      <> l
      <> case rest {
        [] -> ""
        _ -> ", " <> join_label_value_pairs(rest)
      }
  }
}

fn numeric_schema_fields(ctx: SchemaContext) -> List(#(String, glance.Type)) {
  list.filter(ctx.fields, fn(pair) {
    !sql_types.filter_is_string_column(pair.1)
  })
}

fn string_schema_fields(ctx: SchemaContext) -> List(#(String, glance.Type)) {
  list.filter(ctx.fields, fn(pair) { sql_types.filter_is_string_column(pair.1) })
}

fn field_index(fields: List(#(String, a)), label: String) -> Int {
  field_index_loop(fields, label, 0)
}

fn field_index_loop(fields: List(#(String, a)), label: String, i: Int) -> Int {
  case fields {
    [] -> 0
    [#(l, _), ..rest] ->
      case l == label {
        True -> i
        False -> field_index_loop(rest, label, i + 1)
      }
  }
}

