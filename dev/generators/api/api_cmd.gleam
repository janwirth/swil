import generators/api/api_decoders as dec
import generators/api/api_naming as api_naming
import generators/api/api_params as aparam
import generators/api/api_sql
import generators/api/api_update_delete as ud
import generators/api/schema_context
import generators/gleamgen_emit
import generators/migration/migration_sql
import glance
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/import_ as gimport
import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import gleamgen/types/custom as gcustom
import gleamgen/types/variant as gvariant
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

fn command_variant_fields(
  fields: List(FieldDefinition),
  ctx: dec.TypeCtx,
) -> List(#(option.Option(String), gtypes.GeneratedType(gtypes.Dynamic))) {
  list.map(fields, fn(f) {
    #(
      option.Some(f.label),
      gtypes.raw(dec.render_type(f.type_, ctx)) |> gtypes.to_dynamic,
    )
  })
}

fn build_command_custom_type(
  entity: EntityDefinition,
  def: SchemaDefinition,
  ctx: dec.TypeCtx,
) -> gcustom.CustomTypeBuilder(#(), gtypes.Dynamic, #()) {
  let id_def = schema_context.find_identity(def, entity)
  let entity_type = entity.type_name
  let identity_variants =
    list.flat_map(id_def.variants, fn(v) {
      let up_fields = ordered_upsert_fields(entity, v)
      let up_args = command_variant_fields(up_fields, ctx)
      let del_args = command_variant_fields(v.fields, ctx)
      [
        gvariant.new(op_variant_name("Upsert", entity_type, v))
          |> gvariant.with_arguments_dynamic(up_args),
        gvariant.new(op_variant_name("Update", entity_type, v))
          |> gvariant.with_arguments_dynamic(up_args),
        gvariant.new(op_variant_name("Patch", entity_type, v))
          |> gvariant.with_arguments_dynamic(up_args),
        gvariant.new(op_variant_name("Delete", entity_type, v))
          |> gvariant.with_arguments_dynamic(del_args),
      ]
    })
  let data_fields = api_sql.entity_data_fields(entity)
  let by_id_args =
    list.append(
      [#(option.Some("id"), gtypes.int |> gtypes.to_dynamic)],
      command_variant_fields(data_fields, ctx),
    )
  let by_id_variants = [
    gvariant.new("Update" <> entity_type <> "ById")
      |> gvariant.with_arguments_dynamic(by_id_args),
    gvariant.new("Patch" <> entity_type <> "ById")
      |> gvariant.with_arguments_dynamic(by_id_args),
  ]
  let ordered_for_file = list.append(identity_variants, by_id_variants)
  gcustom.new(#())
  |> gcustom.with_dynamic_variants(fn(_) { ordered_for_file })
}

fn entity_sql_constant_entries(
  entity: EntityDefinition,
  def: SchemaDefinition,
) -> List(#(String, String)) {
  let id_def = schema_context.find_identity(def, entity)
  let table = string.lowercase(entity.type_name)
  let data_cols =
    api_sql.entity_data_fields(entity)
    |> list.map(fn(f) { f.label })
  let per_variant =
    list.flat_map(id_def.variants, fn(v) {
      let id_snake = variant_id_snake(v)
      let id_cols = list.map(v.fields, fn(f) { f.label })
      [
        #(
          table <> "_upsert_by_" <> id_snake <> "_sql",
          api_sql.upsert_sql_exec(table, data_cols, id_cols),
        ),
        #(
          table <> "_update_by_" <> id_snake <> "_sql",
          api_sql.update_by_identity_sql_exec(table, data_cols, id_cols),
        ),
        #(
          table <> "_delete_by_" <> id_snake <> "_sql",
          api_sql.soft_delete_by_identity_sql_exec(table, id_cols),
        ),
      ]
    })
  list.append(per_variant, [
    #(
      table <> "_update_by_id_sql",
      api_sql.update_by_row_id_sql_exec(table, data_cols),
    ),
  ])
}

fn generate_entity_cmd_piece(
  def: SchemaDefinition,
  entity: EntityDefinition,
  ctx: dec.TypeCtx,
  scalar_names: List(String),
) -> #(
  String,
  String,
  gcustom.CustomTypeBuilder(#(), gtypes.Dynamic, #()),
  List(#(String, String)),
  String,
  String,
) {
  let id_def = schema_context.find_identity(def, entity)
  let table = string.lowercase(entity.type_name)
  let entity_type = entity.type_name
  let entity_snake = string.lowercase(entity.type_name)
  let command_type_name = entity_type <> "Command"
  let type_builder = build_command_custom_type(entity, def, ctx)
  let const_entries = entity_sql_constant_entries(entity, def)

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
  let tag_case_inner =
    tag_middle
    <> "    Patch"
    <> entity_type
    <> "ById(..) -> "
    <> int.to_string(n_after_variants)
    <> "\n    Update"
    <> entity_type
    <> "ById(..) -> "
    <> int.to_string(n_after_variants + 1)

  #(
    command_type_name,
    entity_snake,
    type_builder,
    const_entries,
    plan_body,
    tag_case_inner,
  )
}

/// Double-quoted Gleam string body: escape `\` and `"` so SQL can span lines.
fn escape_gleam_string_body(s: String) -> String {
  s
  |> string.replace(each: "\\", with: "\\\\")
  |> string.replace(each: "\"", with: "\\\"")
}

fn cmd_module_uses_timestamp(def: SchemaDefinition, ctx: dec.TypeCtx) -> Bool {
  case schema_context.schema_uses_timestamp(def) {
    True -> True
    False ->
      list.any(def.entities, fn(e) {
        let id = schema_context.find_identity(def, e)
        let all_fields =
          list.append(
            api_sql.entity_data_fields(e),
            list.flatten(list.map(id.variants, fn(v) { v.fields })),
          )
        list.any(all_fields, fn(f) {
          string.contains(dec.render_type(f.type_, ctx), "Timestamp")
        })
      })
  }
}

fn import_pre(path: List(String)) -> gimport.ImportedModule {
  gimport.new(path)
  |> gimport.with_predefined(True)
}

/// Plan, variant-tag, and execute functions for one entity (gleamgen `use` chain).
fn entity_cmd_fns_module(
  command_type_name: String,
  entity_snake: String,
  plan_body: String,
  tag_case_inner: String,
  rest: gmod.Module,
) -> gmod.Module {
  use _ <- gmod.with_function(
    gleamgen_emit.pub_def("execute_" <> entity_snake <> "_cmds"),
    gfun.new2(
      gparam.new("conn", gtypes.raw("sqlight.Connection"))
        |> gparam.with_label("conn"),
      gparam.new(
        "commands",
        gtypes.raw("List(" <> command_type_name <> ")"),
      )
        |> gparam.with_label("commands"),
      gtypes.raw("Result(Nil, #(Int, sqlight.Error))"),
      fn(_conn, _commands) {
        gexpr.raw(
          "cmd_runner.run_cmds(conn, commands, "
          <> entity_snake
          <> "_variant_tag, plan_"
          <> entity_snake
          <> ")",
        )
      },
    ),
  )
  use _ <- gmod.with_function(
    gdef.new(entity_snake <> "_variant_tag"),
    gfun.new1(
      gparam.new("cmd", gtypes.raw(command_type_name))
        |> gparam.with_label("cmd"),
      gtypes.int,
      fn(_cmd) {
        gexpr.raw("case cmd {\n" <> tag_case_inner <> "\n  }")
      },
    ),
  )
  use _ <- gmod.with_function(
    gdef.new("plan_" <> entity_snake),
    gfun.new2(
      gparam.new("cmd", gtypes.raw(command_type_name))
        |> gparam.with_label("cmd"),
      gparam.new("now", gtypes.int) |> gparam.with_label("now"),
      gtypes.raw("#(String, List(sqlight.Value))"),
      fn(_cmd, _now) {
        gexpr.raw("case cmd {\n" <> plan_body <> "\n  }")
      },
    ),
  )
  rest
}

fn prepend_entity_cmd_module(
  def: SchemaDefinition,
  entity: EntityDefinition,
  ctx: dec.TypeCtx,
  scalar_names: List(String),
  entity_index: Int,
  rest: gmod.Module,
) -> gmod.Module {
  let #(
    command_type_name,
    entity_snake,
    type_builder,
    const_entries,
    plan_body,
    tag_case_inner,
  ) = generate_entity_cmd_piece(def, entity, ctx, scalar_names)
  let type_def = case entity_index {
    0 ->
      gleamgen_emit.pub_def(command_type_name)
      |> gdef.with_text_before(
        "/// Commands-as-pure-data for this schema's entities.\n/// Generated — do not edit by hand.\n/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.\n",
      )
    _ -> gleamgen_emit.pub_def(command_type_name)
  }
  let fn_tail =
    entity_cmd_fns_module(
      command_type_name,
      entity_snake,
      plan_body,
      tag_case_inner,
      rest,
    )
  let with_consts =
    list.fold_right(const_entries, fn_tail, fn(acc, entry) {
      let #(name, sql) = entry
      gmod.with_constant(gdef.new(name), gexpr.string(sql), fn(_) { acc })
    })
  gmod.with_custom_type_dynamic(type_def, type_builder, fn(_, _) {
    with_consts
  })
}

fn apply_optional_cmd_imports(
  def: SchemaDefinition,
  ctx: dec.TypeCtx,
  scalar_names: List(String),
  sch_parts: List(String),
  row_parts: List(String),
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let k = inner
  let k = case cmd_module_needs_schema(ctx, def) {
    True ->
      fn() {
        gmod.with_import(gimport.new(sch_parts) |> gimport.with_predefined(True), fn(_) {
          k()
        })
      }
    False -> k
  }
  let k = case cmd_module_needs_row(def, scalar_names) {
    True ->
      fn() {
        gmod.with_import(gimport.new(row_parts) |> gimport.with_predefined(True), fn(_) {
          k()
        })
      }
    False -> k
  }
  let k = case cmd_module_uses_timestamp(def, ctx) {
    True ->
      fn() {
        gmod.with_import(
          gimport.new(["gleam", "time", "timestamp"])
            |> gimport.with_exposing([gimport.exposed_type("Timestamp")])
            |> gimport.with_predefined(True),
          fn(_) { k() },
        )
      }
    False -> k
  }
  let k = case schema_needs_calendar(def) {
    True ->
      fn() {
        gmod.with_import(
          gimport.new(["gleam", "time", "calendar"])
            |> gimport.with_predefined(True),
          fn(_) { k() },
        )
      }
    False -> k
  }
  k()
}

fn chain_cmd_module_imports(
  schema_path: String,
  def: SchemaDefinition,
  ctx: dec.TypeCtx,
  scalar_names: List(String),
  build: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  let db_path = schema_context.db_module_path_from_schema(schema_path)
  let db_parts = string.split(db_path, "/")
  let row_parts = list.append(db_parts, ["row"])
  use _ <- gmod.with_import(import_pre(["gleam", "list"]))
  use _ <- gmod.with_import(import_pre(["gleam", "option"]))
  use _ <- gmod.with_import(import_pre(["gleam", "string"]))
  apply_optional_cmd_imports(
    def,
    ctx,
    scalar_names,
    sch_parts,
    row_parts,
    fn() {
      use _ <- gmod.with_import(import_pre(["sqlight"]))
      use _ <- gmod.with_import(import_pre(["swil", "api_help"]))
      use _ <- gmod.with_import(import_pre(["swil", "cmd_runner"]))
      build()
    },
  )
}

/// Emit `cmd.gleam`: per-entity command ADTs, private SQL, planners, and
/// `execute_<entity>_cmds` entry points (see `OPERATIONS_PURE_DATA_SPEC.md`).
pub fn generate_cmd_module(
  schema_path: String,
  def: SchemaDefinition,
) -> String {
  let ctx = dec.type_ctx(schema_path, def)
  let scalar_names = list.map(def.scalars, fn(s) { s.type_name })
  let mod =
    chain_cmd_module_imports(schema_path, def, ctx, scalar_names, fn() {
      list.index_fold(def.entities, gmod.eof(), fn(acc, entity, i) {
        prepend_entity_cmd_module(def, entity, ctx, scalar_names, i, acc)
      })
    })
  gleamgen_emit.render_module(mod)
}
