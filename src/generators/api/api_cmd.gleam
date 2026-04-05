import generators/api/api_decoders as dec
import generators/api/api_naming as api_naming
import generators/api/api_params as aparam
import generators/api/api_sql
import generators/api/api_update_delete as ud
import generators/api/schema_context
import generators/migration/migration_sql
import glance
import gleam/int
import gleam/list
import gleam/string
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition, type IdentityVariantDefinition,
  type SchemaDefinition,
}

fn variant_id_snake(v: IdentityVariantDefinition) -> String {
  case string.starts_with(v.variant_name, "By") {
    True ->
      api_naming.pascal_to_snake(string.drop_start(v.variant_name, 2))
    False -> api_naming.pascal_to_snake(v.variant_name)
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
    _ -> panic as "api_cmd: expected Option(scalar) field"
  }
}

fn render_type_plain_field(t: glance.Type, scalar_names: List(String)) -> String {
  case t {
    glance.NamedType(_, "Int", _, []) -> "Int"
    glance.NamedType(_, "Float", _, []) -> "Float"
    glance.NamedType(_, "String", _, []) -> "String"
    glance.NamedType(_, "Timestamp", _, []) -> "Timestamp"
    glance.NamedType(_, name, _, []) ->
      case list.contains(scalar_names, name) {
        True -> name
        False -> "String"
      }
    _ -> "String"
  }
}

fn render_type_plain(f: FieldDefinition, scalar_names: List(String)) -> String {
  case f.type_ {
    glance.NamedType(_, "Option", _, [inner]) ->
      render_type_plain_field(inner, scalar_names)
    _ -> render_type_plain_field(f.type_, scalar_names)
  }
}

fn type_is_option_date(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Option", _, [glance.NamedType(_, "Date", _, [])]) ->
      True
    _ -> False
  }
}

fn type_is_plain_date(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Date", _, []) -> True
    _ -> False
  }
}

/// Binding for a column value in upsert / update-by-identity (data / identity fields).
fn cmd_bind_typed_value(f: FieldDefinition, value_expr: String) -> String {
  ud.sql_bind_expr(f, value_expr, "_")
}

fn cmd_bind_non_id_data_field(
  f: FieldDefinition,
  label: String,
  scalar_names: List(String),
) -> String {
  case is_option_scalar(f, scalar_names) {
    True -> {
      let value =
        "row."
        <> dec.scalar_to_db_fn_name(scalar_name_from_option_field(f))
        <> "("
        <> label
        <> ")"
      cmd_bind_typed_value(f, value)
    }
    False ->
      case dec.field_is_calendar_date(f) {
        True ->
          case type_is_option_date(f.type_) {
            True ->
              "sqlight.text(case "
              <> label
              <> " {\n        option.Some(d) -> api_help.date_to_db_string(d)\n        option.None -> \"\"\n      })"
            False ->
              case type_is_plain_date(f.type_) {
                True ->
                  "sqlight.text(api_help.date_to_db_string(" <> label <> "))"
                False ->
                  "sqlight.text(case "
                  <> label
                  <> " {\n        option.Some(d) -> api_help.date_to_db_string(d)\n        option.None -> \"\"\n      })"
              }
          }
        False ->
          case render_type_plain(f, scalar_names) {
            "Float" ->
              "sqlight.float(api_help.opt_float_for_db(" <> label <> "))"
            "Int" ->
              "sqlight.int(api_help.opt_int_for_db(" <> label <> "))"
            "Timestamp" ->
              "sqlight.int(api_help.opt_timestamp_for_db(" <> label <> "))"
            _ ->
              "sqlight.text(api_help.opt_text_for_db(" <> label <> "))"
          }
      }
  }
}

fn type_root_is_option(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Option", _, _) -> True
    _ -> False
  }
}

/// SQL `col = ?` fragment as contents of a Gleam string literal (escaped).
fn patch_set_assignment_string_literal(label: String) -> String {
  let frag = migration_sql.quote_ident(label) <> " = ?"
  escape_gleam_string_body(frag)
}

/// Bind expression for the inner value after `Some(...)` in a Patch (non-NULL wire encoding).
fn patch_some_bind(
  f: FieldDefinition,
  inner_var: String,
  scalar_names: List(String),
) -> String {
  case is_option_scalar(f, scalar_names) {
    True -> {
      let scalar = scalar_name_from_option_field(f)
      "sqlight.text(row."
      <> dec.scalar_to_db_fn_name(scalar)
      <> "(option.Some("
      <> inner_var
      <> ")))"
    }
    False ->
      case dec.field_is_calendar_date(f) {
        True ->
          "sqlight.text(api_help.date_to_db_string(" <> inner_var <> "))"
        False ->
          case render_type_plain(f, scalar_names) {
            "Float" -> "sqlight.float(" <> inner_var <> ")"
            "Int" -> "sqlight.int(" <> inner_var <> ")"
            "Timestamp" ->
              "sqlight.int({ let #(s, _) = timestamp.to_unix_seconds_and_nanoseconds("
              <> inner_var
              <> ") s })"
            _ -> "sqlight.text(" <> inner_var <> ")"
          }
      }
  }
}

fn patch_sql_prefix_lit(table: String) -> String {
  escape_gleam_string_body(
    "update " <> migration_sql.quote_ident(table) <> " set ",
  )
}

fn patch_option_field_block(
  f: FieldDefinition,
  ref: String,
  scalar_names: List(String),
) -> String {
  let inner = ref <> "_pv"
  let lit = patch_set_assignment_string_literal(f.label)
  let bind = patch_some_bind(f, inner, scalar_names)
  "      let #(set_parts, binds) = case "
  <> ref
  <> " {\n        option.None -> #(set_parts, binds)\n        option.Some("
  <> inner
  <> ") -> #([\""
  <> lit
  <> "\", ..set_parts], ["
  <> bind
  <> ", ..binds])\n      }\n"
}

fn patch_non_option_field_line(
  f: FieldDefinition,
  ref: String,
  scalar_names: List(String),
) -> String {
  let lit = patch_set_assignment_string_literal(f.label)
  let bind = cmd_bind_non_id_data_field(f, ref, scalar_names)
  "      let #(set_parts, binds) = #([\""
  <> lit
  <> "\", ..set_parts], ["
  <> bind
  <> ", ..binds])\n"
}

fn patch_where_sql_suffix_lit(id_cols: List(String)) -> String {
  let where_id =
    id_cols
    |> list.map(fn(c) { migration_sql.quote_ident(c) <> " = ?" })
    |> string.join(" and ")
  " where "
  <> where_id
  <> " and "
  <> migration_sql.quote_ident("deleted_at")
  <> " is null;"
}

fn patch_identity_plan_case_body(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  scalar_names: List(String),
  field_qualifier: String,
) -> String {
  let table = string.lowercase(entity.type_name)
  let id_cols = list.map(variant.fields, fn(f) { f.label })
  let labels = dec.id_labels_list(variant)
  let data_fields = api_sql.entity_data_fields(entity)
  let non_id =
    list.filter(data_fields, fn(f) { !list.contains(labels, f.label) })
  let field_blocks =
    list.map(non_id, fn(f) {
      let ref = field_qualifier <> f.label
      case type_root_is_option(f.type_) {
        True -> patch_option_field_block(f, ref, scalar_names)
        False -> patch_non_option_field_line(f, ref, scalar_names)
      }
    })
    |> string.concat
  let ut_lit = patch_set_assignment_string_literal("updated_at")
  let sql_prefix_esc = patch_sql_prefix_lit(table)
  let where_esc = escape_gleam_string_body(patch_where_sql_suffix_lit(id_cols))
  let where_binds =
    list.map(variant.fields, fn(f) {
      "          "
      <> cmd_bind_typed_value(f, field_qualifier <> f.label)
      <> ","
    })
    |> string.join("\n")
  "      let #(set_parts, binds) = #([], [])\n"
  <> field_blocks
  <> "      let #(set_parts, binds) = #([\""
  <> ut_lit
  <> "\", ..set_parts], [sqlight.int(now), ..binds])\n"
  <> "      let set_sql = string.join(list.reverse(set_parts), \", \")\n"
  <> "      let sql = \""
  <> sql_prefix_esc
  <> "\" <> set_sql <> \""
  <> where_esc
  <> "\"\n"
  <> "      let binds = list.flatten([list.reverse(binds), [\n"
  <> where_binds
  <> "\n      ]])\n"
  <> "      #(sql, binds)\n"
}

fn patch_by_id_plan_case_body(
  entity: EntityDefinition,
  scalar_names: List(String),
) -> String {
  let table = string.lowercase(entity.type_name)
  let data_fields = api_sql.entity_data_fields(entity)
  let field_blocks =
    list.map(data_fields, fn(f) {
      let ref = f.label
      case type_root_is_option(f.type_) {
        True -> patch_option_field_block(f, ref, scalar_names)
        False -> patch_non_option_field_line(f, ref, scalar_names)
      }
    })
    |> string.concat
  let ut_lit = patch_set_assignment_string_literal("updated_at")
  let sql_prefix_esc = patch_sql_prefix_lit(table)
  let where_esc =
    escape_gleam_string_body(
      " where "
      <> migration_sql.quote_ident("id")
      <> " = ? and "
      <> migration_sql.quote_ident("deleted_at")
      <> " is null;",
    )
  "      let #(set_parts, binds) = #([], [])\n"
  <> field_blocks
  <> "      let #(set_parts, binds) = #([\""
  <> ut_lit
  <> "\", ..set_parts], [sqlight.int(now), ..binds])\n"
  <> "      let set_sql = string.join(list.reverse(set_parts), \", \")\n"
  <> "      let sql = \""
  <> sql_prefix_esc
  <> "\" <> set_sql <> \""
  <> where_esc
  <> "\"\n"
  <> "      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])\n"
  <> "      #(sql, binds)\n"
}

fn upsert_binding_lines(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  scalar_names: List(String),
  field_qualifier: String,
) -> String {
  let labels = dec.id_labels_list(variant)
  let data_fields = api_sql.entity_data_fields(entity)
  let lines =
    list.map(data_fields, fn(f) {
      let ref = field_qualifier <> f.label
      let bind = case list.contains(labels, f.label) {
        True -> cmd_bind_typed_value(f, ref)
        False -> cmd_bind_non_id_data_field(f, ref, scalar_names)
      }
      "        " <> bind <> ","
    })
  string.join(lines, "\n")
  <> "\n        sqlight.int(now),\n        sqlight.int(now),"
}

fn update_by_identity_binding_lines(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  scalar_names: List(String),
  field_qualifier: String,
) -> String {
  let labels = dec.id_labels_list(variant)
  let data_fields = api_sql.entity_data_fields(entity)
  let non_id = list.filter(data_fields, fn(f) { !list.contains(labels, f.label) })
  let set_lines =
    list.map(non_id, fn(f) {
      let ref = field_qualifier <> f.label
      "        "
      <> cmd_bind_non_id_data_field(f, ref, scalar_names)
      <> ","
    })
    |> string.join("\n")
  let where_lines =
    list.map(variant.fields, fn(f) {
      "        "
      <> cmd_bind_typed_value(f, field_qualifier <> f.label)
      <> ","
    })
    |> string.join("\n")
  string.trim_end(set_lines <> "\n        sqlight.int(now),\n" <> where_lines)
}

fn delete_binding_lines(variant: IdentityVariantDefinition) -> String {
  let id_lines =
    list.map(variant.fields, fn(f) {
      "        " <> cmd_bind_typed_value(f, f.label) <> ","
    })
    |> string.join("\n")
  "        sqlight.int(now),\n        sqlight.int(now),\n" <> id_lines
}

fn update_by_id_binding_lines(
  entity: EntityDefinition,
  scalar_names: List(String),
) -> String {
  let data_fields = api_sql.entity_data_fields(entity)
  let lines =
    list.map(data_fields, fn(f) {
      "        " <> cmd_bind_non_id_data_field(f, f.label, scalar_names) <> ","
    })
    |> string.join("\n")
  string.trim_end(lines <> "\n        sqlight.int(now),\n        sqlight.int(id),")
}

fn ordered_upsert_fields(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
) -> List(FieldDefinition) {
  aparam.upsert_ordered_data_fields(entity, variant)
}

fn record_fields_type_lines(
  fields: List(FieldDefinition),
  ctx: dec.TypeCtx,
) -> String {
  list.map(fields, fn(f) {
    "    " <> f.label <> ": " <> dec.render_type(f.type_, ctx) <> ","
  })
  |> string.join("\n")
}

fn variant_pattern_labels(fields: List(FieldDefinition)) -> String {
  list.map(fields, fn(f) { f.label <> ":" })
  |> string.join(", ")
}

fn op_variant_name(
  op: String,
  entity_type: String,
  variant: IdentityVariantDefinition,
) -> String {
  op <> entity_type <> variant.variant_name
}

fn entity_needs_calendar(entity: EntityDefinition) -> Bool {
  list.any(api_sql.entity_data_fields(entity), dec.field_is_calendar_date)
}

fn identity_variant_needs_calendar(v: IdentityVariantDefinition) -> Bool {
  list.any(v.fields, dec.field_is_calendar_date)
}

fn schema_needs_calendar(def: SchemaDefinition) -> Bool {
  list.any(def.entities, fn(e) {
    entity_needs_calendar(e)
    || {
      let id = schema_context.find_identity(def, e)
      list.any(id.variants, identity_variant_needs_calendar)
    }
  })
}

fn cmd_module_needs_row(def: SchemaDefinition, scalar_names: List(String)) -> Bool {
  list.any(def.entities, fn(e) {
    list.any(api_sql.entity_data_fields(e), fn(f) {
      is_option_scalar(f, scalar_names)
    })
  })
}

fn cmd_module_needs_schema(ctx: dec.TypeCtx, def: SchemaDefinition) -> Bool {
  let qualified = fn(f: FieldDefinition) {
    string.contains(dec.render_type(f.type_, ctx), ctx.schema_alias <> ".")
  }
  list.any(def.entities, fn(e) {
    list.any(api_sql.entity_data_fields(e), qualified)
    || {
      let id = schema_context.find_identity(def, e)
      list.any(list.flatten(list.map(id.variants, fn(v) { v.fields })), qualified)
    }
  })
}

fn generate_entity_blocks(
  def: SchemaDefinition,
  entity: EntityDefinition,
  ctx: dec.TypeCtx,
  scalar_names: List(String),
) -> #(String, String, String, String, String) {
  let id_def = schema_context.find_identity(def, entity)
  let table = string.lowercase(entity.type_name)
  let entity_type = entity.type_name
  let entity_snake = string.lowercase(entity.type_name)
  let data_cols =
    api_sql.entity_data_fields(entity)
    |> list.map(fn(f) { f.label })
  let command_type_name = entity_type <> "Command"

  let type_body =
    list.map(id_def.variants, fn(v) {
      let op_base = op_variant_name("Upsert", entity_type, v)
      let up_fields = ordered_upsert_fields(entity, v)
      "  /// Upsert by `"
      <> v.variant_name
      <> "` identity.\n  "
      <> op_base
      <> "(\n"
      <> record_fields_type_lines(up_fields, ctx)
      <> "\n  )\n  /// Update by `"
      <> v.variant_name
      <> "` identity (every non-id column is written; `option.None` uses sentinel / empty DB encoding).\n  "
      <> op_variant_name("Update", entity_type, v)
      <> "(\n"
      <> record_fields_type_lines(up_fields, ctx)
      <> "\n  )\n  /// Partial update by `"
      <> v.variant_name
      <> "` (`option.None` leaves that column unchanged in SQL).\n  "
      <> op_variant_name("Patch", entity_type, v)
      <> "(\n"
      <> record_fields_type_lines(up_fields, ctx)
      <> "\n  )\n  /// Soft-delete by `"
      <> v.variant_name
      <> "` identity.\n  "
      <> op_variant_name("Delete", entity_type, v)
      <> "(\n"
      <> record_fields_type_lines(v.fields, ctx)
      <> "\n  )"
    })
    |> string.join("\n  ")
  let update_by_id_variant =
    "  /// Update all scalar columns by row `id` (same sentinel rules as identity `Update`).\n  Update"
    <> entity_type
    <> "ById(\n    id: Int,\n"
    <> list.map(api_sql.entity_data_fields(entity), fn(f) {
      "    " <> f.label <> ": " <> dec.render_type(f.type_, ctx) <> ","
    })
    |> string.join("\n")
    <> "\n  )\n  /// Partial update by row `id` (`option.None` leaves that column unchanged).\n  Patch"
    <> entity_type
    <> "ById(\n    id: Int,\n"
    <> list.map(api_sql.entity_data_fields(entity), fn(f) {
      "    " <> f.label <> ": " <> dec.render_type(f.type_, ctx) <> ","
    })
    |> string.join("\n")
    <> "\n  )"
  let type_block =
    "pub type "
    <> command_type_name
    <> " {\n"
    <> type_body
    <> "\n  "
    <> update_by_id_variant
    <> "\n}\n"

  let const_block =
    list.map(id_def.variants, fn(v) {
      let id_snake = variant_id_snake(v)
      let id_cols = list.map(v.fields, fn(f) { f.label })
      [
        "const "
        <> table
        <> "_upsert_by_"
        <> id_snake
        <> "_sql = \""
        <> escape_gleam_string_body(api_sql.upsert_sql_exec(
          table,
          data_cols,
          id_cols,
        ))
        <> "\"\n",
        "const "
        <> table
        <> "_update_by_"
        <> id_snake
        <> "_sql = \""
        <> escape_gleam_string_body(api_sql.update_by_identity_sql_exec(
          table,
          data_cols,
          id_cols,
        ))
        <> "\"\n",
        "const "
        <> table
        <> "_delete_by_"
        <> id_snake
        <> "_sql = \""
        <> escape_gleam_string_body(api_sql.soft_delete_by_identity_sql_exec(
          table,
          id_cols,
        ))
        <> "\"\n",
      ]
      |> string.concat
    })
    |> string.concat
    <> "const "
    <> table
    <> "_update_by_id_sql = \""
    <> escape_gleam_string_body(api_sql.update_by_row_id_sql_exec(
      table,
      data_cols,
    ))
    <> "\"\n"

  let plan_cases =
    list.map(id_def.variants, fn(v) {
      let id_snake = variant_id_snake(v)
      let up_fields = ordered_upsert_fields(entity, v)
      let pat = variant_pattern_labels(up_fields)
      let upsert_name = op_variant_name("Upsert", entity_type, v)
      let update_name = op_variant_name("Update", entity_type, v)
      let patch_name = op_variant_name("Patch", entity_type, v)
      let delete_name = op_variant_name("Delete", entity_type, v)
      let upsert_sql_const =
        table <> "_upsert_by_" <> id_snake <> "_sql"
      let update_sql_const = table <> "_update_by_" <> id_snake <> "_sql"
      let delete_sql_const = table <> "_delete_by_" <> id_snake <> "_sql"
      let upsert_binds = upsert_binding_lines(entity, v, scalar_names, "")
      let update_binds =
        update_by_identity_binding_lines(entity, v, scalar_names, "")
      let patch_plan = patch_identity_plan_case_body(entity, v, scalar_names, "")
      let delete_binds = delete_binding_lines(v)
      "    "
      <> upsert_name
      <> "("
      <> pat
      <> ") -> #(\n      "
      <> upsert_sql_const
      <> ",\n      [\n"
      <> upsert_binds
      <> "\n      ],\n    )\n    "
      <> update_name
      <> "("
      <> pat
      <> ") -> #(\n      "
      <> update_sql_const
      <> ",\n      [\n"
      <> update_binds
      <> "\n      ],\n    )\n    "
      <> patch_name
      <> "("
      <> pat
      <> ") -> {\n"
      <> patch_plan
      <> "    }\n    "
      <> delete_name
      <> "("
      <> variant_pattern_labels(v.fields)
      <> ") -> #(\n      "
      <> delete_sql_const
      <> ",\n      [\n"
      <> delete_binds
      <> "\n      ],\n    )"
    })
    |> string.join("\n")
  let update_by_id_pat =
    "id:, "
    <> variant_pattern_labels(api_sql.entity_data_fields(entity))
  let by_id_binds = update_by_id_binding_lines(entity, scalar_names)
  let patch_by_id_body = patch_by_id_plan_case_body(entity, scalar_names)
  let plan_body =
    plan_cases
    <> "\n    Patch"
    <> entity_type
    <> "ById("
    <> update_by_id_pat
    <> ") -> {\n"
    <> patch_by_id_body
    <> "    }\n    Update"
    <> entity_type
    <> "ById("
    <> update_by_id_pat
    <> ") -> #(\n      "
    <> table
    <> "_update_by_id_sql,\n      [\n"
    <> by_id_binds
    <> "\n      ],\n    )"

  let #(n_after_variants, tag_middle) =
    list.fold(id_def.variants, #(0, ""), fn(acc, v) {
      let #(n, text) = acc
      let upsert_name = op_variant_name("Upsert", entity_type, v)
      let update_name = op_variant_name("Update", entity_type, v)
      let patch_name = op_variant_name("Patch", entity_type, v)
      let delete_name = op_variant_name("Delete", entity_type, v)
      let chunk =
        text
        <> "    "
        <> upsert_name
        <> "(..) -> "
        <> int.to_string(n)
        <> "\n    "
        <> update_name
        <> "(..) -> "
        <> int.to_string(n + 1)
        <> "\n    "
        <> patch_name
        <> "(..) -> "
        <> int.to_string(n + 2)
        <> "\n    "
        <> delete_name
        <> "(..) -> "
        <> int.to_string(n + 3)
        <> "\n"
      #(n + 4, chunk)
    })
  let tag_block =
    "fn "
    <> entity_snake
    <> "_variant_tag(cmd: "
    <> command_type_name
    <> ") -> Int {\n  case cmd {\n"
    <> tag_middle
    <> "    Patch"
    <> entity_type
    <> "ById(..) -> "
    <> int.to_string(n_after_variants)
    <> "\n    Update"
    <> entity_type
    <> "ById(..) -> "
    <> int.to_string(n_after_variants + 1)
    <> "\n  }\n}\n"

  let plan_fn =
    "fn plan_"
    <> entity_snake
    <> "(cmd: "
    <> command_type_name
    <> ", now: Int) -> #(String, List(sqlight.Value)) {\n  case cmd {\n"
    <> plan_body
    <> "\n  }\n}\n"

  let exec_fn =
    "pub fn execute_"
    <> entity_snake
    <> "_cmds(\n  conn: sqlight.Connection,\n  commands: List("
    <> command_type_name
    <> "),\n) -> Result(Nil, #(Int, sqlight.Error)) {\n  cmd_runner.run_cmds(conn, commands, "
    <> entity_snake
    <> "_variant_tag, plan_"
    <> entity_snake
    <> ")\n}\n"

  #(type_block, const_block, plan_fn, tag_block, exec_fn)
}

/// Double-quoted Gleam string body: escape `\` and `"` so SQL can span lines.
fn escape_gleam_string_body(s: String) -> String {
  s
  |> string.replace(each: "\\", with: "\\\\")
  |> string.replace(each: "\"", with: "\\\"")
}

/// Emit `cmd.gleam`: per-entity command ADTs, private SQL, planners, and
/// `execute_<entity>_cmds` entry points (see `OPERATIONS_PURE_DATA_SPEC.md`).
pub fn generate_cmd_module(
  schema_path: String,
  def: SchemaDefinition,
) -> String {
  let ctx = dec.type_ctx(schema_path, def)
  let db_path = schema_context.db_module_path_from_schema(schema_path)
  let scalar_names = list.map(def.scalars, fn(s) { s.type_name })
  let blocks =
    list.map(def.entities, fn(e) { generate_entity_blocks(def, e, ctx, scalar_names) })
  let types = list.map(blocks, fn(b) { b.0 }) |> string.concat
  let consts = list.map(blocks, fn(b) { b.1 }) |> string.concat
  let plans = list.map(blocks, fn(b) { b.2 }) |> string.concat
  let tags = list.map(blocks, fn(b) { b.3 }) |> string.concat
  let execs = list.map(blocks, fn(b) { b.4 }) |> string.concat

  let cal_import = case schema_needs_calendar(def) {
    True -> "import gleam/time/calendar\n"
    False -> ""
  }
  let ts_import = case
    schema_context.schema_uses_timestamp(def)
    || string.contains(types, "Timestamp")
  {
    True -> "import gleam/time/timestamp.{type Timestamp}\n"
    False -> ""
  }
  let row_import = case cmd_module_needs_row(def, scalar_names) {
    True -> "import " <> db_path <> "/row\n"
    False -> ""
  }
  let schema_import = case cmd_module_needs_schema(ctx, def) {
    True -> "import " <> schema_path <> "\n"
    False -> ""
  }

  "/// Commands-as-pure-data for this schema's entities.\n/// Generated — do not edit by hand.\n/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.\nimport gleam/list\nimport gleam/option\nimport gleam/string\n"
  <> cal_import
  <> ts_import
  <> row_import
  <> schema_import
  <> "import sqlight\nimport swil/api_help\nimport swil/cmd_runner\n\n"
  <> types
  <> "\n"
  <> consts
  <> "\n"
  <> plans
  <> tags
  <> execs
}
