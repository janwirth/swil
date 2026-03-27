import generators/api/api_decoders as dec
import generators/api/api_params
import generators/gleamgen_emit
import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type QueryParameter, type QuerySpecDefinition,
  Query, QueryParameter,
  BooleanFilter, CustomOrder, NoneOrBase,
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

pub fn query_spec_targets_entity(
  spec: QuerySpecDefinition,
  entity: EntityDefinition,
) -> Bool {
  case spec.parameters {
    [QueryParameter(_, _, t), _, _] -> type_named_entity(t, entity.type_name)
    _ -> False
  }
}

pub fn schema_query_param_name(p: QueryParameter) -> String {
  case p.label {
    Some(l) -> l
    None -> p.name
  }
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
  list.reverse(
    list.fold(specs, [], fn(acc, spec) {
      case query_fn_chunk_for_spec(entity_snake, row_t, sql_err, ctx, spec) {
        Ok(chunk) -> [chunk, ..acc]
        Error(Nil) -> acc
      }
    }),
  )
}

fn query_fn_chunk_for_spec(
  entity_snake: String,
  row_t,
  sql_err,
  ctx: dec.TypeCtx,
  spec: QuerySpecDefinition,
) {
  let query = spec.query
  let non_shape_params = case spec.parameters {
    [_, _, simple] -> [simple]
    _ -> []
  }
  case query {
    Query(
      shape: NoneOrBase,
      filter: Some(BooleanFilter(
        left_operand_field_name: _,
        operator: _,
        right_operand_parameter_name: right_operand_parameter_name,
      )),
      order: CustomOrder(field: _, direction: _),
    ) -> {
      let bind_param =
        list.find(non_shape_params, fn(p) {
          schema_query_param_name(p) == right_operand_parameter_name
          || p.name == right_operand_parameter_name
        })
      case bind_param {
        Ok(p) ->
          Ok(#(
            gleamgen_emit.pub_def(spec.name),
            gfun.new_raw(
              list.append(
                [api_params.conn_param()],
                list.map(non_shape_params, fn(param) {
                  gparam.new(
                    schema_query_param_name(param),
                    gtypes.raw(dec.render_type(param.type_, ctx)),
                  )
                  |> gparam.to_dynamic
                }),
              ),
              gtypes.result(gtypes.list(row_t), sql_err),
              fn(_) {
                gexpr.raw(eq_missing_field_order_query_body(
                  entity_snake,
                  query_sql_const_name(spec.name),
                  query_bind_expr_for_param(p),
                  "row",
                ))
              },
            )
              |> gfun.to_dynamic,
          ))
        Error(Nil) -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}
