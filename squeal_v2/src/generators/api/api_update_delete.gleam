import generators/api/api_decoders as dec
import generators/api/api_sql
import generators/gleamgen_emit
import generators/sql_types
import glance
import gleam/list
import gleam/option.{None}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition, type IdentityVariantDefinition,
}

pub fn sql_bind_expr(
  f: FieldDefinition,
  value: String,
  _row_qualifier: String,
) -> String {
  case sql_types.sql_type(f.type_) {
    "int" -> "sqlight.int(" <> value <> ")"
    "real" -> "sqlight.float(" <> value <> ")"
    _ ->
      case dec.field_is_calendar_date(f) {
        True -> "sqlight.text(api_help.date_to_db_string(" <> value <> "))"
        False -> "sqlight.text(" <> value <> ")"
      }
  }
}

fn non_id_temp_var(f: FieldDefinition, scalar_names: List(String)) -> String {
  case render_type_plain(f, scalar_names) {
    "String" -> "c"
    "Float" -> "p"
    "Int" -> "q"
    _ -> "db_" <> f.label
  }
}

fn render_type_plain(f: FieldDefinition, scalar_names: List(String)) -> String {
  case f.type_ {
    glance.NamedType(_, "Option", _, [inner]) ->
      render_type_plain_field(inner, scalar_names)
    _ -> render_type_plain_field(f.type_, scalar_names)
  }
}

fn render_type_plain_field(t: glance.Type, scalar_names: List(String)) -> String {
  case t {
    glance.NamedType(_, "Int", None, []) -> "Int"
    glance.NamedType(_, "Float", None, []) -> "Float"
    glance.NamedType(_, "String", None, []) -> "String"
    glance.NamedType(_, name, _, []) ->
      case list.contains(scalar_names, name) {
        True -> name
        False -> "String"
      }
    _ -> "String"
  }
}

fn is_option_scalar(f: FieldDefinition, scalar_names: List(String)) -> Bool {
  case f.type_ {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, n, _, [])]) ->
      list.contains(scalar_names, n)
    _ -> False
  }
}

fn scalar_name_from_option_field(f: FieldDefinition) -> String {
  case f.type_ {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, n, _, [])]) -> n
    _ -> panic as "api_update_delete: expected Option(scalar) field"
  }
}

pub fn upsert_fn_body(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  op_prefix: String,
  scalar_names: List(String),
  row_qualifier: String,
  sql_const_name: String,
  not_found_fn_name: String,
) -> String {
  let labels = dec.id_labels_list(variant)
  let data_fields = api_sql.entity_data_fields(entity)
  let non_id =
    list.filter(data_fields, fn(f) { !list.contains(labels, f.label) })
  let let_lines =
    list.map(non_id, fn(f) {
      case is_option_scalar(f, scalar_names) {
        True -> ""
        False -> {
          let v = non_id_temp_var(f, scalar_names)
          case render_type_plain(f, scalar_names) {
            "String" ->
              "  let "
              <> v
              <> " = api_help.opt_text_for_db("
              <> f.label
              <> ")\n"
            "Float" ->
              "  let "
              <> v
              <> " = api_help.opt_float_for_db("
              <> f.label
              <> ")\n"
            "Int" ->
              "  let " <> v <> " = api_help.opt_int_for_db(" <> f.label <> ")\n"
            _ ->
              "  let "
              <> v
              <> " = api_help.opt_text_for_db("
              <> f.label
              <> ")\n"
          }
        }
      }
    })
    |> string.concat
  let with_list = case op_prefix {
    "upsert" -> {
      let row_bind = fn(col: String) -> String {
        case list.find(variant.fields, fn(f) { f.label == col }) {
          Ok(f) -> "      " <> sql_bind_expr(f, f.label, row_qualifier) <> ","
          Error(_) -> {
            let assert Ok(f) = list.find(non_id, fn(x) { x.label == col })
            let value = case is_option_scalar(f, scalar_names) {
              True ->
                row_qualifier
                <> "."
                <> dec.scalar_to_db_fn_name(scalar_name_from_option_field(f))
                <> "("
                <> f.label
                <> ")"
              False -> non_id_temp_var(f, scalar_names)
            }
            "      " <> sql_bind_expr(f, value, row_qualifier) <> ","
          }
        }
      }
      let id_part =
        list.map(list.map(data_fields, fn(f) { f.label }), row_bind)
        |> string.join("\n")
      string.trim_end(
        id_part <> "\n      sqlight.int(now),\n      sqlight.int(now),",
      )
    }
    _ -> {
      let extras =
        list.map(non_id, fn(f) {
          let value = case is_option_scalar(f, scalar_names) {
            True ->
              row_qualifier
              <> "."
              <> dec.scalar_to_db_fn_name(scalar_name_from_option_field(f))
              <> "("
              <> f.label
              <> ")"
            False -> non_id_temp_var(f, scalar_names)
          }
          "      " <> sql_bind_expr(f, value, row_qualifier) <> ","
        })
        |> string.join("\n")
      let id_tail =
        list.map(variant.fields, fn(f) {
          "      " <> sql_bind_expr(f, f.label, row_qualifier) <> ","
        })
        |> string.join("\n")
      string.trim_end(extras <> "\n      sqlight.int(now),\n" <> id_tail)
    }
  }
  let case_rows = case op_prefix {
    "upsert" ->
      "  case rows {\n    [r, ..] -> Ok(r)\n    [] ->\n      Error(sqlight.SqlightError(\n        sqlight.GenericError,\n        \"upsert returned no row\",\n        -1,\n      ))\n  }"
    _ ->
      "  case rows {\n    [r, ..] -> Ok(r)\n    [] -> Error("
      <> not_found_fn_name
      <> "(\"update_"
      <> entity_snake
      <> "_by_"
      <> id_snake
      <> "\"))\n  }"
  }
  let let_block = case let_lines {
    "" -> ""
    s -> s
  }
  "let now = api_help.unix_seconds_now()\n"
  <> let_block
  <> "  use rows <- result.try(sqlight.query(\n    "
  <> sql_const_name
  <> ",\n    on: conn,\n    with: [\n"
  <> with_list
  <> "\n    ],\n    expecting: "
  <> row_qualifier
  <> "."
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  ))\n"
  <> case_rows
}

pub fn delete_fn_body(
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  row_qualifier: String,
  sql_const_name: String,
  not_found_fn_name: String,
) -> String {
  let id_binds =
    list.map(variant.fields, fn(f) { sql_bind_expr(f, f.label, row_qualifier) })
  let with_elems =
    list.flatten([["sqlight.int(now)", "sqlight.int(now)"], id_binds])
  let with_part = case list.length(variant.fields) > 1 {
    True -> {
      let lines =
        list.map(with_elems, fn(e) { "        " <> e <> "," })
        |> string.join("\n")
      "[\n" <> lines <> "\n      ]"
    }
    False -> "[" <> string.join(with_elems, ", ") <> "]"
  }
  "let now = api_help.unix_seconds_now()\n  use rows <- result.try(\n    sqlight.query(\n      "
  <> sql_const_name
  <> ",\n      on: conn,\n      with: "
  <> with_part
  <> ",\n      expecting: {\n        use _n <- decode.field(0, decode.string)\n        decode.success(Nil)\n      },\n    ),\n  )\n  case rows {\n    [Nil, ..] -> Ok(Nil)\n    [] -> Error("
  <> not_found_fn_name
  <> "(\"delete_"
  <> entity_snake
  <> "_by_"
  <> id_snake
  <> "\"))\n  }"
}

pub fn delete_fn_chunk(
  entity_snake: String,
  id_snake: String,
  variant: IdentityVariantDefinition,
  get_params: List(gparam.Parameter(gtypes.Dynamic)),
  sql_err: gtypes.GeneratedType(e),
  sql_const_name: String,
  not_found_fn_name: String,
) -> #(gdef.Definition, gfun.Function(gtypes.Dynamic, gtypes.Dynamic)) {
  #(
    gleamgen_emit.pub_def("delete_" <> entity_snake <> "_by_" <> id_snake)
      |> gdef.with_text_before(
        "/// Delete a "
        <> entity_snake
        <> " by the `"
        <> variant.variant_name
        <> "` identity.\n",
      ),
    gfun.new_raw(get_params, gtypes.result(gtypes.nil, sql_err), fn(_) {
      gexpr.raw(delete_fn_body(
        variant,
        entity_snake,
        id_snake,
        "row",
        sql_const_name,
        not_found_fn_name,
      ))
    })
      |> gfun.to_dynamic,
  )
}

pub fn update_fn_chunk(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  upsert_params: List(gparam.Parameter(gtypes.Dynamic)),
  row_t: gtypes.GeneratedType(r),
  sql_err: gtypes.GeneratedType(e),
  scalar_names: List(String),
  not_found_fn_name: String,
) -> #(gdef.Definition, gfun.Function(gtypes.Dynamic, gtypes.Dynamic)) {
  #(
    gleamgen_emit.pub_def("update_" <> entity_snake <> "_by_" <> id_snake)
      |> gdef.with_text_before(
        "/// Update a "
        <> entity_snake
        <> " by the `"
        <> variant.variant_name
        <> "` identity.\n",
      ),
    gfun.new_raw(upsert_params, gtypes.result(row_t, sql_err), fn(_) {
      gexpr.raw(upsert_fn_body(
        entity,
        variant,
        entity_snake,
        id_snake,
        "update",
        scalar_names,
        "row",
        "update_" <> entity_snake <> "_by_" <> id_snake <> "_sql",
        not_found_fn_name,
      ))
    })
      |> gfun.to_dynamic,
  )
}
