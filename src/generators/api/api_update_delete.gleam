import generators/api/api_decoders as dec
import generators/api/api_params as aparam
import generators/api/api_sql
import generators/gleamgen_emit
import generators/sql_types
import gleam/list
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

fn identity_get_call_args(variant: IdentityVariantDefinition) -> String {
  list.map(variant.fields, fn(f) { f.label <> ": " <> f.label })
  |> string.join(", ")
}

fn upsert_cmd_field_args(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
) -> String {
  list.map(aparam.upsert_ordered_data_fields(entity, variant), fn(f) {
    f.label <> ": " <> f.label
  })
  |> string.join(", ")
}

fn update_by_id_cmd_args(entity: EntityDefinition) -> String {
  let data = api_sql.entity_data_fields(entity)
  let parts =
    list.map(data, fn(f) { f.label <> ": " <> f.label })
  "id: id, " <> string.join(parts, ", ")
}

/// Uses `cmd.execute_*_cmds` + `get.*` so mutations share the command planner.
pub fn upsert_via_cmd_fn_body(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  entity_type: String,
  id_snake: String,
) -> String {
  let upsert_cmd = "Upsert" <> entity_type <> variant.variant_name
  let cmd_args = upsert_cmd_field_args(entity, variant)
  let get_fn = "get.get_" <> entity_snake <> "_by_" <> id_snake
  let get_args = identity_get_call_args(variant)
  "case cmd.execute_"
  <> entity_snake
  <> "_cmds(conn, [cmd."
  <> upsert_cmd
  <> "("
  <> cmd_args
  <> ")]) {\n  Error(#(_, e)) -> Error(e)\n  Ok(Nil) -> {\n    use row_opt <- result.try("
  <> get_fn
  <> "(conn, "
  <> get_args
  <> "))\n    case row_opt {\n      option.Some(r) -> Ok(r)\n      option.None ->\n        Error(sqlight.SqlightError(\n          sqlight.GenericError,\n          \"upsert returned no row\",\n          -1,\n        ))\n    }\n  }\n}"
}

pub fn update_by_identity_via_cmd_fn_body(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  entity_type: String,
  id_snake: String,
  not_found_fn_name: String,
) -> String {
  let update_cmd = "Update" <> entity_type <> variant.variant_name
  let cmd_args = upsert_cmd_field_args(entity, variant)
  let get_fn = "get.get_" <> entity_snake <> "_by_" <> id_snake
  let get_args = identity_get_call_args(variant)
  let op = "\"update_" <> entity_snake <> "_by_" <> id_snake <> "\""
  "use existing <- result.try("
  <> get_fn
  <> "(conn, "
  <> get_args
  <> "))\ncase existing {\n  option.None -> Error("
  <> not_found_fn_name
  <> "("
  <> op
  <> "))\n  option.Some(_) -> {\n    case cmd.execute_"
  <> entity_snake
  <> "_cmds(conn, [cmd."
  <> update_cmd
  <> "("
  <> cmd_args
  <> ")]) {\n      Error(#(_, e)) -> Error(e)\n      Ok(Nil) -> {\n        use row_opt <- result.try("
  <> get_fn
  <> "(conn, "
  <> get_args
  <> "))\n        case row_opt {\n          option.Some(r) -> Ok(r)\n          option.None -> Error("
  <> not_found_fn_name
  <> "("
  <> op
  <> "))\n        }\n      }\n    }\n  }\n}"
}

pub fn update_by_id_via_cmd_fn_body(
  entity: EntityDefinition,
  entity_snake: String,
  entity_type: String,
  not_found_fn_name: String,
) -> String {
  let cmd_args = update_by_id_cmd_args(entity)
  let update_cmd = "Update" <> entity_type <> "ById"
  let op = "\"update_" <> entity_snake <> "_by_id\""
  "use existing <- result.try(get.get_"
  <> entity_snake
  <> "_by_id(conn, id))\ncase existing {\n  option.None -> Error("
  <> not_found_fn_name
  <> "("
  <> op
  <> "))\n  option.Some(_) -> {\n    case cmd.execute_"
  <> entity_snake
  <> "_cmds(conn, [cmd."
  <> update_cmd
  <> "("
  <> cmd_args
  <> ")]) {\n      Error(#(_, e)) -> Error(e)\n      Ok(Nil) -> {\n        use row_opt <- result.try(get.get_"
  <> entity_snake
  <> "_by_id(conn, id))\n        case row_opt {\n          option.Some(r) -> Ok(r)\n          option.None -> Error("
  <> not_found_fn_name
  <> "("
  <> op
  <> "))\n        }\n      }\n    }\n  }\n}"
}

pub fn delete_via_cmd_fn_body(
  variant: IdentityVariantDefinition,
  entity_snake: String,
  entity_type: String,
  id_snake: String,
  not_found_fn_name: String,
) -> String {
  let del_cmd = "Delete" <> entity_type <> variant.variant_name
  let get_fn = "get.get_" <> entity_snake <> "_by_" <> id_snake
  let get_args = identity_get_call_args(variant)
  let op = "\"delete_" <> entity_snake <> "_by_" <> id_snake <> "\""
  "use existing <- result.try("
  <> get_fn
  <> "(conn, "
  <> get_args
  <> "))\ncase existing {\n  option.None -> Error("
  <> not_found_fn_name
  <> "("
  <> op
  <> "))\n  option.Some(_) -> {\n    case cmd.execute_"
  <> entity_snake
  <> "_cmds(conn, [cmd."
  <> del_cmd
  <> "("
  <> get_args
  <> ")]) {\n      Ok(Nil) -> Ok(Nil)\n      Error(#(_, e)) -> Error(e)\n    }\n  }\n}"
}

pub fn upsert_many_fn_body(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  ctx: dec.TypeCtx,
) -> String {
  let fn_name = "upsert_" <> entity_snake <> "_by_" <> id_snake
  let ordered = aparam.upsert_ordered_data_fields(entity, variant)
  let inner_params =
    list.map(ordered, fn(f) {
      f.label <> ": " <> dec.render_type(f.type_, ctx)
    })
    |> string.join(", ")
  let forward_args =
    list.map(ordered, fn(f) { f.label <> ": " <> f.label })
    |> string.join(", ")
  "list.try_map(items, fn(item) {\n    let upsert_row = fn("
  <> inner_params
  <> ") { "
  <> fn_name
  <> "(conn, "
  <> forward_args
  <> ") }\n    each(item, upsert_row)\n  })"
}

pub fn delete_fn_chunk(
  entity: EntityDefinition,
  entity_snake: String,
  id_snake: String,
  variant: IdentityVariantDefinition,
  get_params: List(gparam.Parameter(gtypes.Dynamic)),
  sql_err: gtypes.GeneratedType(e),
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
      gexpr.raw(delete_via_cmd_fn_body(
        variant,
        entity_snake,
        entity.type_name,
        id_snake,
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
  _scalar_names: List(String),
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
      gexpr.raw(update_by_identity_via_cmd_fn_body(
        entity,
        variant,
        entity_snake,
        entity.type_name,
        id_snake,
        not_found_fn_name,
      ))
    })
      |> gfun.to_dynamic,
  )
}

pub fn update_by_id_fn_chunk(
  entity: EntityDefinition,
  entity_snake: String,
  params: List(gparam.Parameter(gtypes.Dynamic)),
  row_t: gtypes.GeneratedType(r),
  sql_err: gtypes.GeneratedType(e),
  _scalar_names: List(String),
  not_found_fn_name: String,
) -> #(gdef.Definition, gfun.Function(gtypes.Dynamic, gtypes.Dynamic)) {
  #(
    gleamgen_emit.pub_def("update_" <> entity_snake <> "_by_id")
      |> gdef.with_text_before(
        "/// Update a "
        <> entity_snake
        <> " by row id (all scalar columns, including natural-key fields).\n",
      ),
    gfun.new_raw(params, gtypes.result(row_t, sql_err), fn(_) {
      gexpr.raw(update_by_id_via_cmd_fn_body(
        entity,
        entity_snake,
        entity.type_name,
        not_found_fn_name,
      ))
    })
      |> gfun.to_dynamic,
  )
}
