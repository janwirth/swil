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
  case spec.codegen {
    LtMissingFieldAsc(shape_param: shape_param, column: _, threshold_param: _) ->
      list.any(spec.parameters, fn(p) {
        p.name == shape_param && type_named_entity(p.type_, entity.type_name)
      })
    EqMissingFieldOrder(
      shape_param: shape_param,
      filter_column: _,
      match_param: _,
      order_column: _,
      order_desc: _,
    ) ->
      list.any(spec.parameters, fn(p) {
        p.name == shape_param && type_named_entity(p.type_, entity.type_name)
      })
    Unsupported -> False
  }
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
) {
  list.map(specs, fn(spec) {
    case spec.codegen {
      LtMissingFieldAsc(
        column: column,
        threshold_param: threshold_param,
        shape_param: shape_param,
      ) -> {
        let const_nm = query_sql_const_name(spec.name)
        let body =
          lt_missing_field_asc_query_body(
            entity_snake,
            const_nm,
            threshold_param,
            "row",
          )
        let fn_params =
          list.append(
            [api_params.conn_param()],
            list.map(
              list.filter(spec.parameters, fn(p) {
                p.name != shape_param && !type_is_magic_fields(p.type_)
              }),
              fn(p) {
                gparam.new(
                  schema_query_param_name(p),
                  gtypes.raw(dec.render_type(p.type_, ctx)),
                )
                |> gparam.to_dynamic
              },
            ),
          )
        let doc =
          "/// `"
          <> column
          <> " < "
          <> threshold_param
          <> "`, ordered ascending by `"
          <> column
          <> "` (from `"
          <> spec.name
          <> "` query spec).\n"
        #(
          gleamgen_emit.pub_def(spec.name)
            |> gdef.with_text_before(doc),
          gfun.new_raw(fn_params, gtypes.result(gtypes.list(row_t), sql_err), fn(_) {
            gexpr.raw(body)
          })
            |> gfun.to_dynamic,
        )
      }
      EqMissingFieldOrder(
        filter_column: filter_column,
        match_param: match_param,
        shape_param: shape_param,
        order_column: order_column,
        order_desc: order_desc,
      ) -> {
        let assert Ok(match_param_def) =
          list.find(spec.parameters, fn(p) { p.name == match_param })
        let const_nm = query_sql_const_name(spec.name)
        let body =
          eq_missing_field_order_query_body(
            entity_snake,
            const_nm,
            query_bind_expr_for_param(match_param_def),
            "row",
          )
        let fn_params =
          list.append(
            [api_params.conn_param()],
            list.map(
              list.filter(spec.parameters, fn(p) {
                p.name != shape_param && !type_is_magic_fields(p.type_)
              }),
              fn(p) {
                gparam.new(
                  schema_query_param_name(p),
                  gtypes.raw(dec.render_type(p.type_, ctx)),
                )
                |> gparam.to_dynamic
              },
            ),
          )
        let order_dir = case order_desc {
          True -> "descending"
          False -> "ascending"
        }
        let doc =
          "/// `"
          <> filter_column
          <> " == "
          <> match_param
          <> "`, ordered "
          <> order_dir
          <> " by `"
          <> order_column
          <> "` (from `"
          <> spec.name
          <> "` query spec).\n"
        #(
          gleamgen_emit.pub_def(spec.name)
            |> gdef.with_text_before(doc),
          gfun.new_raw(fn_params, gtypes.result(gtypes.list(row_t), sql_err), fn(_) {
            gexpr.raw(body)
          })
            |> gfun.to_dynamic,
        )
      }
      Unsupported ->
        panic as "api_query.generated_query_fn_chunks: unsupported query spec"
    }
  })
}
