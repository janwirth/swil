//// Query spec extraction for schema tooling.
////
//// Walks Glance function definitions and builds [`QuerySpecDefinition`](#QuerySpecDefinition) values for
//// public functions that return a query pipeline. Each spec
//// records the function name, typed parameters, and a [`QueryCodegen`](#QueryCodegen) tag when the tail call
//// matches a pattern generators understand; otherwise codegen is [`Unsupported`](#Unsupported).
////
//// **Naming:** public query functions must be prefixed with `query_`. Public `BooleanFilter` helpers must use
//// the `predicate_` prefix and an explicit `-> ... BooleanFilter` annotation; they are skipped here and are
//// not emitted as query specs.
////
//// **Inference:** the body’s final expression must be a query pipeline:
//// `query(...) |> shape(...) |> order(...)`, with an optional filter step:
//// `dsl.filter(...)`, `dsl.filter_bool(...)`, or `dsl.filter_complex(..., predicate_fn)`.
//// Supported shapes are detected structurally (for example
//// `LtMissingFieldAsc` for `exclude_if_missing` + float threshold + ascending `order` on the same field).

import dsl/dsl
import glance
import gleam/list
import gleam/option.{type Option, None, Some, from_result, then}
import gleam/result
import gleam/string
import schema_definition/parse_error.{
  type ParseError, UnsupportedSchema, hint_public_function_prefixes,
}
import schema_definition/schema_definition as sd

/// Extracted metadata for a public `query_*` function: its name, parameter list, and parsed query.
pub type QuerySpecDefinition {
  QuerySpecDefinition(
    /// Function name as declared in the schema module.
    name: String,
    /// Parameters in source order; every parameter must be type-annotated on public query functions.
    parameters: List(QueryParameter),
    query: sd.Query,
  )
}

/// One formal parameter of a query spec, including optional Gleam label and Glance type AST.
pub type QueryParameter {
  QueryParameter(
    /// `Some(label)` when the parameter uses a labelled argument at the call site; `None` when unlabelled.
    label: Option(String),
    name: String,
    type_: glance.Type,
  )
}

/// Scans module functions and returns every public `query_*` spec, or `ParseError` when
/// rules are violated (missing param types, wrong prefixes, or a public function that is neither a query pipeline nor
/// an annotated `predicate_*` BooleanFilter helper). Private functions and valid `predicate_*` helpers are ignored.
pub fn extract_from_functions(
  functions: List(glance.Definition(glance.Function)),
) -> Result(List(QuerySpecDefinition), ParseError) {
  list.try_fold(functions, [], fn(acc, def) {
    case def {
      glance.Definition(_, f) ->
        case f.publicity {
          glance.Private -> Ok(acc)
          glance.Public ->
            case function_has_let_statements(f) {
              True ->
                Error(UnsupportedSchema(
                  Some(f.location),
                  "public function "
                    <> f.name
                    <> " must not contain `let` statements; use a single expression pipeline",
                ))
              False ->
                case function_is_query_spec(f) {
                  True ->
                    case function_has_query_prefix(f.name) {
                      False ->
                        Error(UnsupportedSchema(
                          Some(f.location),
                          "public query function "
                            <> f.name
                            <> " must start with `query_`. "
                            <> hint_public_function_prefixes(),
                        ))
                      True ->
                        case query_spec_from_function_strict(f) {
                          Ok(spec) -> Ok([spec, ..acc])
                          Error(e) -> Error(e)
                        }
                    }
                  False ->
                    case function_is_boolean_filter_helper(f) {
                      True ->
                        case function_has_predicate_prefix(f.name) {
                          True -> Ok(acc)
                          False ->
                            Error(UnsupportedSchema(
                              Some(f.location),
                              "public BooleanFilter helper "
                                <> f.name
                                <> " must start with `predicate_`. "
                                <> hint_public_function_prefixes(),
                            ))
                        }
                      False ->
                        Error(UnsupportedSchema(
                          Some(f.location),
                          "public function "
                            <> f.name
                            <> " is not allowed in a squeal schema module. "
                            <> hint_public_function_prefixes(),
                        ))
                    }
                }
            }
        }
    }
  })
  |> result.map(list.reverse)
}

fn function_has_let_statements(f: glance.Function) -> Bool {
  list.any(f.body, fn(stmt) {
    case stmt {
      glance.Expression(_) -> False
      _ -> True
    }
  })
}

fn query_spec_from_function_strict(
  f: glance.Function,
) -> Result(QuerySpecDefinition, ParseError) {
  list.try_fold(f.parameters, [], fn(acc, p) {
    case p.type_ {
      None ->
        Error(UnsupportedSchema(
          Some(f.location),
          "public query " <> f.name <> " parameters must have type annotations",
        ))
      Some(t) ->
        Ok([QueryParameter(p.label, assignment_name_string(p.name), t), ..acc])
    }
  })
  |> result.try(fn(params) {
    let params = list.reverse(params)
    case validate_query_parameters_strict(f, params) {
      Ok(Nil) ->
        infer_query(f)
        |> result.map(fn(q) { QuerySpecDefinition(f.name, params, q) })
      Error(e) -> Error(e)
    }
  })
}

/// Query parameter contract for simplified generation:
/// 1) entity object, 2) `dsl.MagicFields`, 3) one simple bind (`Int`/`Float`/`Bool`/`String` or `*Scalar`).
fn validate_query_parameters_strict(
  f: glance.Function,
  params: List(QueryParameter),
) -> Result(Nil, ParseError) {
  case params {
    [
      QueryParameter(_, _entity_name, entity_t),
      QueryParameter(_, _magic_name, magic_t),
      QueryParameter(_, _simple_name, simple_t),
    ] ->
      case
        type_is_entity_parameter(entity_t),
        type_is_magic_fields_parameter(magic_t),
        type_is_simple_parameter(simple_t)
      {
        True, True, True -> Ok(Nil)
        _, _, _ ->
          Error(UnsupportedSchema(
            Some(f.location),
            "public query "
              <> f.name
              <> " parameters must be `(entity, dsl.MagicFields, simple)` where simple is "
              <> "Int/Float/Bool/String or a `*Scalar` type",
          ))
      }
    _ ->
      Error(UnsupportedSchema(
        Some(f.location),
        "public query "
          <> f.name
          <> " must have exactly 3 parameters: `(entity, dsl.MagicFields, simple)`",
      ))
  }
}

/// Optional filter step between `shape` and `order` (see [`parse_query_pipeline_tail`](#parse_query_pipeline_tail)).
type PipelineFilter {
  BoolFilter(glance.Expression)
  ComplexFilter(glance.Expression, glance.Expression)
}

type ParsedPipeline {
  ParsedPipeline(
    shape_value: glance.Expression,
    filter_: Option(PipelineFilter),
    order_field: glance.Expression,
    order_direction: glance.Expression,
  )
}

/// Dispatches structural query inference when the function body ends in a query pipeline.
fn infer_query(f: glance.Function) -> Result(sd.Query, ParseError) {
  case function_tail_expression(f.body) {
    None ->
      Error(UnsupportedSchema(
        Some(f.location),
        "query " <> f.name <> " must end with a query pipeline expression",
      ))
    Some(tail) ->
      case parse_query_pipeline_tail(tail) {
        None ->
          Error(UnsupportedSchema(
            Some(f.location),
            "query "
              <> f.name
              <> " must match `query |> shape |> [dsl.filter | dsl.filter_bool | dsl.filter_complex]? |> dsl.order(field, direction)`",
          ))
        Some(parts) -> {
          use shape <- result.try(parse_shape_expr(f, parts.shape_value))
          use filter <- result.try(case parts.filter_ {
            None -> Ok(None)
            Some(BoolFilter(e)) -> parse_filter_expr(f, e)
            Some(ComplexFilter(spec, pred)) ->
              parse_filter_complex(f, spec, pred)
          })
          use order <- result.try(parse_order_expr(
            f,
            parts.order_field,
            parts.order_direction,
          ))
          Ok(sd.Query(shape: shape, filter: filter, order: order))
        }
      }
  }
}

fn parse_filter_complex(
  f: glance.Function,
  spec_expr: glance.Expression,
  pred_expr: glance.Expression,
) -> Result(Option(sd.Filter), ParseError) {
  use filter_param <- result.try(reference_name_strict(f, spec_expr))
  use pred_name <- result.try(reference_name_strict(f, pred_expr))
  use _ <- result.try(case string.starts_with(pred_name, "predicate_") {
    False ->
      Error(UnsupportedSchema(
        Some(expression_span(normalize_expr(pred_expr))),
        "filter_complex second argument must reference a `predicate_*` function",
      ))
    True -> Ok(Nil)
  })
  let param_names =
    list.map(f.parameters, fn(p) { assignment_name_string(p.name) })
  use _ <- result.try(case list.contains(param_names, filter_param) {
    False ->
      Error(UnsupportedSchema(
        Some(expression_span(normalize_expr(spec_expr))),
        "filter_complex first argument must be a query parameter name",
      ))
    True -> Ok(Nil)
  })
  Ok(
    Some(sd.ComplexRecursive(
      filter_param_name: filter_param,
      predicate_fn_name: pred_name,
    )),
  )
}

fn reference_name_strict(
  f: glance.Function,
  expr: glance.Expression,
) -> Result(String, ParseError) {
  case expression_reference_name(expr) {
    Some(n) -> Ok(n)
    None ->
      Error(UnsupportedSchema(
        Some(expression_span(normalize_expr(expr))),
        "query "
          <> f.name
          <> " filter_complex arguments must be simple name references",
      ))
  }
}

fn expression_reference_name(expr: glance.Expression) -> Option(String) {
  case normalize_expr(expr) {
    glance.Variable(_, name) -> Some(name)
    glance.FieldAccess(_, inner, label) ->
      case expression_reference_name(inner) {
        Some(_) -> Some(label)
        None -> Some(label)
      }
    _ -> None
  }
}

fn parse_shape_expr(
  f: glance.Function,
  shape_expr: glance.Expression,
) -> Result(sd.Shape, ParseError) {
  let entity_name = case f.parameters {
    [first, ..] -> assignment_name_string(first.name)
    [] -> ""
  }
  case normalize_expr(shape_expr) {
    glance.Variable(_, "None") -> Ok(sd.NoneOrBase)
    glance.FieldAccess(_, _, "None") -> Ok(sd.NoneOrBase)
    glance.Variable(_, root) if root == entity_name -> Ok(sd.NoneOrBase)
    glance.Tuple(_, elements) ->
      list.try_fold(elements, [], fn(acc, el) {
        use item <- result.try(parse_shape_item(f, el))
        Ok([item, ..acc])
      })
      |> result.map(fn(items) { sd.Subset(selection: list.reverse(items)) })
    _ ->
      Error(UnsupportedSchema(
        Some(f.location),
        "query " <> f.name <> " shape must be the entity or a tuple projection",
      ))
  }
}

fn parse_shape_item(
  f: glance.Function,
  expr: glance.Expression,
) -> Result(sd.ShapeItem, ParseError) {
  case normalize_expr(expr) {
    glance.Tuple(_, [glance.String(_, alias), value]) -> {
      use parsed <- result.try(parse_expr(f, value))
      Ok(sd.ShapeField(alias: Some(alias), expr: parsed))
    }
    other -> {
      use parsed <- result.try(parse_expr(f, other))
      case derive_shape_alias(parsed) {
        Some(alias) -> Ok(sd.ShapeField(alias: Some(alias), expr: parsed))
        None ->
          Error(UnsupportedSchema(
            Some(f.location),
            "query "
              <> f.name
              <> " shape field alias is required for ambiguous expressions",
          ))
      }
    }
  }
}

fn parse_filter_expr(
  f: glance.Function,
  filter_expr: glance.Expression,
) -> Result(Option(sd.Filter), ParseError) {
  case is_none_expr(filter_expr) {
    True -> Ok(None)
    False ->
      parse_pred(f, filter_expr)
      |> result.map(fn(pred) { Some(sd.Predicate(pred)) })
  }
}

/// Source span for diagnostics (underlines the expression, not the whole `query_*` function).
fn expression_span(e: glance.Expression) -> glance.Span {
  case e {
    glance.Int(location: s, ..) -> s
    glance.Float(location: s, ..) -> s
    glance.String(location: s, ..) -> s
    glance.Variable(location: s, ..) -> s
    glance.NegateInt(location: s, ..) -> s
    glance.NegateBool(location: s, ..) -> s
    glance.Block(location: s, ..) -> s
    glance.Panic(location: s, ..) -> s
    glance.Todo(location: s, ..) -> s
    glance.Tuple(location: s, ..) -> s
    glance.List(location: s, ..) -> s
    glance.Fn(location: s, ..) -> s
    glance.RecordUpdate(location: s, ..) -> s
    glance.FieldAccess(location: s, ..) -> s
    glance.Call(location: s, ..) -> s
    glance.TupleIndex(location: s, ..) -> s
    glance.FnCapture(location: s, ..) -> s
    glance.BitString(location: s, ..) -> s
    glance.Case(location: s, ..) -> s
    glance.BinaryOperator(location: s, ..) -> s
    glance.Echo(location: s, ..) -> s
  }
}

fn parse_pred(
  f: glance.Function,
  expr: glance.Expression,
) -> Result(sd.Pred, ParseError) {
  case normalize_expr(expr) {
    glance.BinaryOperator(_, glance.And, left, right) -> {
      use l <- result.try(parse_pred(f, left))
      use r <- result.try(parse_pred(f, right))
      Ok(sd.And(items: [l, r]))
    }
    glance.BinaryOperator(_, glance.Or, left, right) -> {
      use l <- result.try(parse_pred(f, left))
      use r <- result.try(parse_pred(f, right))
      Ok(sd.Or(items: [l, r]))
    }
    glance.NegateBool(_, value) -> {
      use inner <- result.try(parse_pred(f, value))
      Ok(sd.Not(item: inner))
    }
    glance.BinaryOperator(_, op, left, right) -> {
      use left_expr <- result.try(parse_expr(f, left))
      use right_expr <- result.try(parse_expr(f, right))
      use operator <- result.try(operator_from_binary(f, op))
      use missing_behavior <- result.try(infer_missing_behavior(f, left_expr))
      Ok(sd.Compare(
        left: left_expr,
        operator: operator,
        right: right_expr,
        missing_behavior: missing_behavior,
      ))
    }
    _ -> {
      let at = expression_span(normalize_expr(expr))
      Error(UnsupportedSchema(
        Some(at),
        "in `"
          <> f.name
          <> "`, the expression passed to `dsl.filter_bool` / `dsl.filter` (see span above) is not a structured predicate "
          <> "this parser understands yet — it expects comparisons such as "
          <> "`dsl.exclude_if_missing(entity.field) <. param`. "
          <> "A call like `dsl.complex_filter(...)` is valid Gleam but is not yet extracted into the query AST.",
      ))
    }
  }
}

fn parse_order_expr(
  f: glance.Function,
  field_expr: glance.Expression,
  dir_expr: glance.Expression,
) -> Result(sd.Order, ParseError) {
  case is_none_expr(field_expr) {
    True -> Ok(sd.UpdatedAtDesc)
    False -> {
      use parsed_expr <- result.try(parse_expr(f, field_expr))
      use direction <- result.try(order_direction(dir_expr, f))
      Ok(sd.CustomOrder(expr: parsed_expr, direction: direction))
    }
  }
}

fn parse_expr(
  f: glance.Function,
  expr: glance.Expression,
) -> Result(sd.Expr, ParseError) {
  case normalize_expr(expr) {
    glance.Variable(_, name) ->
      case simple_bind_param_name(f) == Some(name) {
        True -> Ok(sd.Param(name: name))
        False -> Ok(sd.Field(path: [name]))
      }
    glance.FieldAccess(_, _, _) -> parse_field_access_expr(f, expr)
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Ok("exclude_if_missing") ->
          parse_call_with_single_arg(f, sd.ExcludeIfMissingFn, args)
        Ok("nullable") -> parse_call_with_single_arg(f, sd.NullableFn, args)
        Ok("age") -> parse_call_with_single_arg(f, sd.AgeFn, args)
        Ok(name) ->
          Error(UnsupportedSchema(
            Some(f.location),
            "query " <> f.name <> " uses unsupported function " <> name,
          ))
        Error(Nil) ->
          Error(UnsupportedSchema(
            Some(f.location),
            "query " <> f.name <> " contains unsupported call expression",
          ))
      }
    _ ->
      Error(UnsupportedSchema(
        Some(f.location),
        "query " <> f.name <> " contains unsupported expression",
      ))
  }
}

fn parse_call_with_single_arg(
  f: glance.Function,
  fn_: sd.ExprFn,
  args: List(glance.Field(glance.Expression)),
) -> Result(sd.Expr, ParseError) {
  case single_unlabelled_arg(args) {
    Some(inner) -> {
      use parsed <- result.try(parse_expr(f, inner))
      Ok(sd.Call(func: fn_, args: [parsed]))
    }
    None ->
      Error(UnsupportedSchema(
        Some(f.location),
        "query " <> f.name <> " call must have one unlabelled argument",
      ))
  }
}

fn operator_from_binary(
  f: glance.Function,
  op: glance.BinaryOperator,
) -> Result(sd.Operator, ParseError) {
  case op {
    glance.LtInt -> Ok(sd.Lt)
    glance.LtFloat -> Ok(sd.Lt)
    glance.Eq -> Ok(sd.Eq)
    glance.GtInt -> Ok(sd.Gt)
    glance.GtFloat -> Ok(sd.Gt)
    glance.LtEqInt -> Ok(sd.Le)
    glance.LtEqFloat -> Ok(sd.Le)
    glance.GtEqInt -> Ok(sd.Ge)
    glance.GtEqFloat -> Ok(sd.Ge)
    glance.NotEq -> Ok(sd.Ne)
    _ ->
      Error(UnsupportedSchema(
        Some(f.location),
        "query " <> f.name <> " uses unsupported comparison operator",
      ))
  }
}

fn infer_missing_behavior(
  f: glance.Function,
  expr: sd.Expr,
) -> Result(sd.MissingBehavior, ParseError) {
  case expr {
    sd.Call(func: sd.NullableFn, args: _) -> Ok(sd.Nullable)
    sd.Call(func: sd.ExcludeIfMissingFn, args: _) -> Ok(sd.ExcludeIfMissing)
    sd.Call(func: _, args: args) ->
      case list.find_map(args, fn(arg) { infer_missing_behavior(f, arg) }) {
        Ok(v) -> Ok(v)
        Error(Nil) ->
          Error(UnsupportedSchema(
            Some(f.location),
            "query "
              <> f.name
              <> " filter must use exclude_if_missing(...) or nullable(...)",
          ))
      }
    _ ->
      Error(UnsupportedSchema(
        Some(f.location),
        "query "
          <> f.name
          <> " filter must use exclude_if_missing(...) or nullable(...)",
      ))
  }
}

fn derive_shape_alias(expr: sd.Expr) -> Option(String) {
  case expr {
    sd.Field(path: path) -> list.last(path) |> from_result
    sd.Call(func: sd.AgeFn, args: _) -> Some("age")
    sd.Call(func: sd.ExcludeIfMissingFn, args: [sd.Field(path: path)]) ->
      list.last(path) |> from_result
    sd.Call(func: sd.NullableFn, args: [sd.Field(path: path)]) ->
      list.last(path) |> from_result
    _ -> None
  }
}

fn parse_field_access_expr(
  f: glance.Function,
  expr: glance.Expression,
) -> Result(sd.Expr, ParseError) {
  case normalize_expr(expr) {
    glance.FieldAccess(_, inner, label) -> {
      use parsed_inner <- result.try(parse_expr(f, inner))
      case parsed_inner {
        sd.Field(path: path) -> Ok(sd.Field(path: list.append(path, [label])))
        sd.Call(func: sd.NullableFn, args: [sd.Field(path: path)]) ->
          Ok(
            sd.Call(func: sd.NullableFn, args: [
              sd.Field(path: list.append(path, [label])),
            ]),
          )
        _ ->
          Error(UnsupportedSchema(
            Some(f.location),
            "query "
              <> f.name
              <> " contains unsupported field access expression",
          ))
      }
    }
    _ ->
      Error(UnsupportedSchema(
        Some(f.location),
        "query " <> f.name <> " contains unsupported field access expression",
      ))
  }
}

fn is_none_expr(expr: glance.Expression) -> Bool {
  case normalize_expr(expr) {
    glance.Variable(_, "None") -> True
    glance.FieldAccess(_, _, "None") -> True
    _ -> False
  }
}

fn order_direction(
  expr: glance.Expression,
  f: glance.Function,
) -> Result(dsl.Direction, ParseError) {
  case normalize_expr(expr) {
    glance.FieldAccess(_, _, "Asc") -> Ok(dsl.Asc)
    glance.Variable(_, "Asc") -> Ok(dsl.Asc)
    glance.FieldAccess(_, _, "Desc") -> Ok(dsl.Desc)
    glance.Variable(_, "Desc") -> Ok(dsl.Desc)
    _ ->
      Error(UnsupportedSchema(
        Some(f.location),
        "query " <> f.name <> " order direction must be dsl.Asc or dsl.Desc",
      ))
  }
}

/// Last statement of a body when it is a bare expression; used as the “tail” of a function or block.
fn function_tail_expression(
  body: List(glance.Statement),
) -> Option(glance.Expression) {
  case list.last(body) {
    Ok(glance.Expression(e)) -> Some(e)
    _ -> None
  }
}

/// Strips a trailing block down to its final expression so nested calls / field access match predictably.
fn normalize_expr(expr: glance.Expression) -> glance.Expression {
  case expr {
    glance.Block(_, stmts) ->
      case function_tail_expression(stmts) {
        Some(inner) -> normalize_expr(inner)
        None -> expr
      }
    _ -> expr
  }
}

/// Parses `dsl.order(inner, field, direction)`; `inner` is the rest of the pipeline.
fn peel_order_call(
  expr: glance.Expression,
) -> Option(#(glance.Expression, glance.Expression, glance.Expression)) {
  case normalize_expr(expr) {
    glance.Call(_, order_callee, order_args) ->
      case
        expression_callee_name(order_callee),
        three_unlabelled_args(order_args)
      {
        Ok("order"), Some(#(before_order, field, dir)) ->
          Some(#(before_order, field, dir))
        _, _ -> None
      }
    _ -> None
  }
}

/// After `order`, optional `dsl.filter` / `dsl.filter_bool` / `dsl.filter_complex` wrapping `shape(query(..), ..)`.
fn peel_optional_filter_before_shape(
  expr: glance.Expression,
) -> #(glance.Expression, Option(PipelineFilter)) {
  case normalize_expr(expr) {
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Ok("filter") | Ok("filter_bool") ->
          case two_unlabelled_args(args) {
            Some(#(rest, pred)) -> #(rest, Some(BoolFilter(pred)))
            None -> #(expr, None)
          }
        Ok("filter_complex") ->
          case three_unlabelled_args(args) {
            Some(#(rest, spec, pred)) -> #(
              rest,
              Some(ComplexFilter(spec, pred)),
            )
            None -> #(expr, None)
          }
        _ -> #(expr, None)
      }
    _ -> #(expr, None)
  }
}

/// `shape(query(entity), shape_value)` → `Some(shape_value)`.
fn peel_shape_query_call(expr: glance.Expression) -> Option(glance.Expression) {
  case normalize_expr(expr) {
    glance.Call(_, shape_callee, shape_args) ->
      case
        expression_callee_name(shape_callee),
        two_unlabelled_args(shape_args)
      {
        Ok("shape"), Some(#(query_expr, shape_value_expr)) ->
          case normalize_expr(query_expr) {
            glance.Call(_, query_callee, query_args) ->
              case
                expression_callee_name(query_callee),
                single_unlabelled_arg(query_args)
              {
                Ok("query"), Some(_entity) -> Some(shape_value_expr)
                _, _ -> None
              }
            _ -> None
          }
        _, _ -> None
      }
    _ -> None
  }
}

/// Nested calls: `order( [filter_*]( shape(query(..), val) , ...)? , field , direction )`.
fn query_pipeline_nested_calls(
  expr: glance.Expression,
) -> Option(ParsedPipeline) {
  use #(before_order, field, dir) <- then(peel_order_call(expr))
  let #(shape_call, filter_) = peel_optional_filter_before_shape(before_order)
  use shape_value <- then(peel_shape_query_call(shape_call))
  Some(ParsedPipeline(shape_value, filter_, field, dir))
}

/// `query(entity) |> shape(..)` segment when the AST still has `|>` (0 or 1 filter steps handled by caller).
fn finish_pipe_shape_segment(
  expr: glance.Expression,
  order_field: glance.Expression,
  order_direction: glance.Expression,
) -> Option(ParsedPipeline) {
  case normalize_expr(expr) {
    glance.BinaryOperator(_, _, query_step, shape_step) -> {
      use shape_value <- then(single_named_call_arg(shape_step, "shape"))
      case normalize_expr(query_step) {
        glance.Call(_, query_callee, query_args) ->
          case
            expression_callee_name(query_callee),
            single_unlabelled_arg(query_args)
          {
            Ok("query"), Some(_) ->
              Some(ParsedPipeline(
                shape_value,
                None,
                order_field,
                order_direction,
              ))
            _, _ -> None
          }
        _ -> None
      }
    }
    _ -> None
  }
}

/// Recursively peel `.. |> filter_*` then resolve `query |> shape`.
fn collect_pipeline_from_pipe_left(
  left_chain: glance.Expression,
  order_field: glance.Expression,
  order_direction: glance.Expression,
) -> Option(ParsedPipeline) {
  case normalize_expr(left_chain) {
    glance.BinaryOperator(_, _, inner_left, rhs) ->
      case normalize_expr(rhs) {
        glance.Call(_, callee, args) ->
          case expression_callee_name(callee) {
            Ok("filter") | Ok("filter_bool") ->
              case single_unlabelled_arg(args) {
                Some(pred) ->
                  collect_pipeline_from_pipe_left(
                    inner_left,
                    order_field,
                    order_direction,
                  )
                  |> then(fn(base) {
                    case base.filter_ {
                      None ->
                        Some(ParsedPipeline(
                          base.shape_value,
                          Some(BoolFilter(pred)),
                          base.order_field,
                          base.order_direction,
                        ))
                      Some(_) -> None
                    }
                  })
                None ->
                  finish_pipe_shape_segment(
                    left_chain,
                    order_field,
                    order_direction,
                  )
              }
            Ok("filter_complex") ->
              case two_unlabelled_args(args) {
                Some(#(spec, pred)) ->
                  collect_pipeline_from_pipe_left(
                    inner_left,
                    order_field,
                    order_direction,
                  )
                  |> then(fn(base) {
                    case base.filter_ {
                      None ->
                        Some(ParsedPipeline(
                          base.shape_value,
                          Some(ComplexFilter(spec, pred)),
                          base.order_field,
                          base.order_direction,
                        ))
                      Some(_) -> None
                    }
                  })
                None ->
                  finish_pipe_shape_segment(
                    left_chain,
                    order_field,
                    order_direction,
                  )
              }
            _ ->
              finish_pipe_shape_segment(
                left_chain,
                order_field,
                order_direction,
              )
          }
        _ -> finish_pipe_shape_segment(left_chain, order_field, order_direction)
      }
    _ -> finish_pipe_shape_segment(left_chain, order_field, order_direction)
  }
}

fn query_pipeline_pipe_components(
  expr: glance.Expression,
) -> Option(ParsedPipeline) {
  case normalize_expr(expr) {
    glance.BinaryOperator(_, _, left_chain, order_step) -> {
      use #(order_field, order_direction) <- then(two_unlabelled_named_call(
        order_step,
        "order",
      ))
      collect_pipeline_from_pipe_left(left_chain, order_field, order_direction)
    }
    _ -> None
  }
}

fn parse_query_pipeline_tail(expr: glance.Expression) -> Option(ParsedPipeline) {
  case query_pipeline_nested_calls(expr) {
    Some(p) -> Some(p)
    None -> query_pipeline_pipe_components(expr)
  }
}

fn single_named_call_arg(
  expr: glance.Expression,
  name: String,
) -> Option(glance.Expression) {
  case normalize_expr(expr) {
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Ok(n) if n == name -> single_unlabelled_arg(args)
        _ -> None
      }
    _ -> None
  }
}

/// `name(a, b)` with two unlabelled arguments (e.g. `dsl.order(field, dsl.Asc)` on the RHS of `|>`).
fn two_unlabelled_named_call(
  expr: glance.Expression,
  name: String,
) -> Option(#(glance.Expression, glance.Expression)) {
  case normalize_expr(expr) {
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Ok(n) if n == name -> two_unlabelled_args(args)
        _ -> None
      }
    _ -> None
  }
}

/// Call must have exactly one unlabelled argument (e.g. `exclude_if_missing(shape.col)`).
fn single_unlabelled_arg(
  args: List(glance.Field(glance.Expression)),
) -> Option(glance.Expression) {
  case args {
    [glance.UnlabelledField(e)] -> Some(e)
    _ -> None
  }
}

/// Call must have exactly two unlabelled arguments.
fn two_unlabelled_args(
  args: List(glance.Field(glance.Expression)),
) -> Option(#(glance.Expression, glance.Expression)) {
  case args {
    [glance.UnlabelledField(a), glance.UnlabelledField(b)] -> Some(#(a, b))
    _ -> None
  }
}

fn three_unlabelled_args(
  args: List(glance.Field(glance.Expression)),
) -> Option(#(glance.Expression, glance.Expression, glance.Expression)) {
  case args {
    [
      glance.UnlabelledField(a),
      glance.UnlabelledField(b),
      glance.UnlabelledField(c),
    ] -> Some(#(a, b, c))
    _ -> None
  }
}

fn simple_bind_param_name(f: glance.Function) -> Option(String) {
  case f.parameters {
    [_, _, p] -> Some(assignment_name_string(p.name))
    _ -> None
  }
}

/// Builtin simple bind types accepted in the third slot.
fn type_is_builtin_simple(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Int", None, []) -> True
    glance.NamedType(_, "Float", None, []) -> True
    glance.NamedType(_, "Bool", None, []) -> True
    glance.NamedType(_, "String", None, []) -> True
    _ -> False
  }
}

/// Third-slot simple type: primitive or schema scalar (`*Scalar`).
fn type_is_simple_parameter(t: glance.Type) -> Bool {
  case type_is_builtin_simple(t) {
    True -> True
    False ->
      case t {
        glance.NamedType(_, name, _, []) -> string.ends_with(name, "Scalar")
        _ -> False
      }
  }
}

/// Second slot must be `dsl.MagicFields` (qualified or unqualified).
fn type_is_magic_fields_parameter(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "MagicFields", _, []) -> True
    _ -> False
  }
}

/// First slot is a user entity type (not simple, not `MagicFields`).
fn type_is_entity_parameter(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, name, _, []) ->
      name != "MagicFields" && !type_is_simple_parameter(t)
    _ -> False
  }
}

/// Query spec candidate: body whose last expression builds a query pipeline.
fn function_is_query_spec(f: glance.Function) -> Bool {
  case function_has_query_prefix(f.name) {
    True -> True
    False ->
      case f.return {
        Some(_) -> False
        None -> statements_return_query(f.body)
      }
  }
}

/// Public helpers that build `dsl.BooleanFilter` trees are allowed alongside query specs.
/// They are not emitted as `QuerySpecDefinition`; name them `predicate_*` with an explicit
/// `-> ... BooleanFilter` return annotation.
fn function_is_boolean_filter_helper(f: glance.Function) -> Bool {
  case f.return {
    Some(t) -> type_is_boolean_filter(t)
    None -> False
  }
}

/// Named type with constructor name `BooleanFilter`.
fn type_is_boolean_filter(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "BooleanFilter", _, _) -> True
    _ -> False
  }
}

/// Last statement is an expression whose tail calls `order(...)` in a query pipeline.
fn statements_return_query(body: List(glance.Statement)) -> Bool {
  case list.last(body) {
    Error(Nil) -> False
    Ok(stmt) ->
      case stmt {
        glance.Expression(e) -> expression_is_query_in_tail(e)
        _ -> False
      }
  }
}

/// Used when there is no return annotation: last expr is query pipeline tail.
fn expression_is_query_in_tail(expr: glance.Expression) -> Bool {
  case normalize_expr(expr) {
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Ok("order") ->
          case three_unlabelled_args(args) {
            Some(_) -> True
            None -> False
          }
        _ -> False
      }
    glance.BinaryOperator(_, _, _, rhs) ->
      case two_unlabelled_named_call(rhs, "order") {
        Some(_) -> True
        None -> False
      }
    glance.Block(_, stmts) -> statements_return_query(stmts)
    _ -> False
  }
}

/// Best-effort callee label for `f()` / `mod.f()`: variable name or final segment of a field access.
fn expression_callee_name(expr: glance.Expression) -> Result(String, Nil) {
  case expr {
    glance.Variable(_, name) -> Ok(name)
    glance.FieldAccess(_, _inner, label) -> Ok(label)
    _ -> Error(Nil)
  }
}

/// Gleam parameter or pattern name as a string, including discarded placeholders.
fn assignment_name_string(name: glance.AssignmentName) -> String {
  case name {
    glance.Named(s) -> s
    glance.Discarded(s) -> s
  }
}

/// Public query spec functions must start with `query_`.
fn function_has_query_prefix(name: String) -> Bool {
  string.starts_with(name, "query_")
}

/// Public `BooleanFilter` helpers must start with `predicate_`.
fn function_has_predicate_prefix(name: String) -> Bool {
  string.starts_with(name, "predicate_")
}
