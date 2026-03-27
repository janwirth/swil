import generators/api/api_decoders as dec
import generators/api/api_params
import generators/gleamgen_emit
import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type QueryParameter, type QuerySpecDefinition,
  EqMissingFieldOrder, LtMissingFieldAsc, Unsupported,
}

pub fn query_sql_const_name(spec_name: String) -> String {
  case string.starts_with(spec_name, "query_") {
    True -> string.drop_start(spec_name, 6) <> "_sql"
    False -> spec_name <> "_sql"
  }
}

fn type_named_entity(t: glance.Type, entity_name: String) -> Bool {
  case t {
    glance.NamedType(_, n, None, []) if n == entity_name -> True
    glance.NamedType(_, n, Some(_), []) if n == entity_name -> True
    _ -> False
  }
}

fn type_is_magic_fields(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "MagicFields", _, []) -> True
    _ -> False
  }
}

pub fn query_spec_targets_entity(
  spec: QuerySpecDefinition,
  entity: EntityDefinition,
) -> Bool {
  todo
}

pub fn schema_query_param_name(p: QueryParameter) -> String {
  case p.label {
    Some(l) -> l
    None -> p.name
  }
}

fn lt_missing_field_asc_query_body(
  entity_snake: String,
  sql_const: String,
  threshold_param: String,
  decoder_qualifier: String,
) -> String {
  "sqlight.query(\n    "
  <> sql_const
  <> ",\n    on: conn,\n    with: [sqlight.float("
  <> threshold_param
  <> ")],\n    expecting: "
  <> decoder_qualifier
  <> "."
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  )"
}

fn eq_missing_field_order_query_body(
  entity_snake: String,
  sql_const: String,
  match_bind_expr: String,
  decoder_qualifier: String,
) -> String {
  "sqlight.query(\n    "
  <> sql_const
  <> ",\n    on: conn,\n    with: ["
  <> match_bind_expr
  <> "],\n    expecting: "
  <> decoder_qualifier
  <> "."
  <> entity_snake
  <> "_with_magic_row_decoder(),\n  )"
}

fn query_bind_expr_for_param(p: QueryParameter) -> String {
  case p.type_ {
    glance.NamedType(_, "Int", _, []) ->
      "sqlight.int(" <> schema_query_param_name(p) <> ")"
    glance.NamedType(_, "Float", _, []) ->
      "sqlight.float(" <> schema_query_param_name(p) <> ")"
    glance.NamedType(_, "Bool", _, []) ->
      "sqlight.int(case " <> schema_query_param_name(p) <> " { True -> 1 False -> 0 })"
    glance.NamedType(_, "String", _, []) ->
      "sqlight.text(" <> schema_query_param_name(p) <> ")"
    glance.NamedType(_, name, _, []) ->
      "sqlight.text(row."
      <> dec.scalar_to_db_fn_name(name)
      <> "(Some("
      <> schema_query_param_name(p)
      <> ")))"
    _ -> "sqlight.text(" <> schema_query_param_name(p) <> ")"
  }
}

pub fn generated_query_fn_chunks(
  entity_snake: String,
  row_t,
  sql_err,
  ctx: dec.TypeCtx,
  specs: List(QuerySpecDefinition),
) {todo}
