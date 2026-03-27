//// Query spec extraction for schema tooling.
////
//// Walks Glance function definitions and builds [`QuerySpecDefinition`](#QuerySpecDefinition) values for
//// public functions that return a query pipeline. Each spec
//// records the function name, typed parameters, and a [`QueryCodegen`](#QueryCodegen) tag when the tail call
//// matches a pattern generators understand; otherwise codegen is [`Unsupported`](#Unsupported).
////
//// **Naming:** public query functions must be prefixed with `query_`. Public `BooleanFilter` helpers used in
//// nested filters must use the `filter_` prefix and an explicit `-> ... BooleanFilter` annotation; they are
//// skipped here and are not emitted as specs.
////
//// **Inference:** the body’s final expression must be a query pipeline
//// (`query(...) |> shape(...) |> filter(...) |> order(...)`).
//// Supported shapes are detected structurally (for example
//// `LtMissingFieldAsc` for `exclude_if_missing` + float threshold + ascending `order_by` on the same field).

import glance
import gleam/list
import gleam/option.{type Option, None, Some, from_result, then}
import gleam/result
import gleam/string
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}

/// How (or whether) a schema [`QuerySpecDefinition`](#QuerySpecDefinition) maps to generated SQL in tooling.
pub type QueryCodegen {
  /// Shape/filter/order not recognized; skeleton and API may emit TODOs for this spec.
  Unsupported
  /// `exclude_if_missing(shape.{column}) <. threshold` with `order_by(shape.{column}, Asc)` on the same column.
  /// `threshold_param` must be a `Float` function parameter; `shape_param` names the entity parameter.
  LtMissingFieldAsc(
    column: String,
    threshold_param: String,
    shape_param: String,
  )
}

/// Extracted metadata for a public `query_*` function: its name, parameter list, and inferred codegen.
pub type QuerySpecDefinition {
  QuerySpecDefinition(
    /// Function name as declared in the schema module.
    name: String,
    /// Parameters in source order; every parameter must be type-annotated on public query functions.
    parameters: List(QueryParameter),
    /// Structural match for SQL/API generation, or [`Unsupported`](#Unsupported) when the tail query expression does not match a known pattern.
    codegen: QueryCodegen,
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
/// an annotated `filter_*` BooleanFilter helper). Private functions and valid `filter_*` helpers are ignored.
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
                            <> " must start with `query_`",
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
                        case function_has_filter_prefix(f.name) {
                          True -> Ok(acc)
                          False ->
                            Error(UnsupportedSchema(
                              Some(f.location),
                              "public BooleanFilter helper "
                                <> f.name
                                <> " must start with `filter_`",
                            ))
                        }
                      False ->
                        Error(UnsupportedSchema(
                          Some(f.location),
                          "public function "
                            <> f.name
                            <> " must build a query pipeline (`query |> shape |> filter |> order`) "
                            <> "or return BooleanFilter (annotation) for nested filter helpers",
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
      Ok(Nil) -> Ok(QuerySpecDefinition(f.name, params, infer_query_codegen(f)))
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

/// Dispatches structural codegen inference when the function body ends in a query pipeline.
fn infer_query_codegen(f: glance.Function) -> QueryCodegen {
  case function_tail_expression(f.body) {
    None -> Unsupported
    Some(tail) ->
      case query_tail_components(tail) {
        None -> infer_lt_missing_field_asc_fallback(f)
        Some(#(shape_expr, filter_expr, order_expr)) ->
          infer_lt_missing_field_asc(f, shape_expr, filter_expr, order_expr)
      }
  }
}

fn infer_lt_missing_field_asc_fallback(f: glance.Function) -> QueryCodegen {
  case f.parameters {
    [shape_p, _, _] -> {
      let shape_name = assignment_name_string(shape_p.name)
      case
        find_lt_missing_predicate_in_statements(f.body, shape_name),
        find_order_by_column_in_statements(f.body, shape_name)
      {
        Some(#(column, threshold_name)), Some(order_col) ->
          case column == order_col && param_is_float_named(f, threshold_name) {
            True -> LtMissingFieldAsc(column, threshold_name, shape_name)
            False -> Unsupported
          }
        _, _ -> Unsupported
      }
    }
    _ -> Unsupported
  }
}

/// Recognises [`LtMissingFieldAsc`](#LtMissingFieldAsc): optional filter with `exclude_if_missing` on a shape field,
/// `<.` against a float parameter, and ascending `order_by` on that same field.
fn infer_lt_missing_field_asc(
  f: glance.Function,
  shape_expr: glance.Expression,
  filter_expr: glance.Expression,
  order_expr: glance.Expression,
) -> QueryCodegen {
  case lt_missing_field_asc_match(f, shape_expr, filter_expr, order_expr) {
    Some(#(column, threshold_name, shape_name)) ->
      LtMissingFieldAsc(column, threshold_name, shape_name)
    None -> Unsupported
  }
}

/// `filter` path → threshold param + column on `shape_name`, if it matches `exclude_if_missing(shape.col) <. threshold`.
fn lt_missing_field_asc_match(
  f: glance.Function,
  shape_expr: glance.Expression,
  filter_expr: glance.Expression,
  order_expr: glance.Expression,
) -> Option(#(String, String, String)) {
  use shape_name <- then(expect_variable_name(shape_expr))
  let raw_pred = case unwrap_some_call(filter_expr) {
    Some(inner) -> inner
    None -> filter_expr
  }
  use pred <- then(unwrap_predicate_filter_value(raw_pred))
  use #(threshold_name, column) <- then(lt_float_exclude_shape_field(
    pred,
    shape_name,
  ))
  use order_col <- then(from_result(query_order_column(order_expr, shape_name)))
  case column == order_col && param_is_float_named(f, threshold_name) {
    True -> Some(#(column, threshold_name, shape_name))
    False -> None
  }
}

/// `left <. threshold_var` where `left` is `exclude_if_missing(shape_field)` for this `shape_name`.
fn lt_float_exclude_shape_field(
  pred: glance.Expression,
  shape_name: String,
) -> Option(#(String, String)) {
  case pred {
    glance.BinaryOperator(
      _,
      glance.LtFloat,
      left,
      glance.Variable(_, threshold_name),
    ) ->
      case exclude_if_missing_column_on_shape(left, shape_name) {
        Some(column) -> Some(#(threshold_name, column))
        None -> None
      }
    _ -> None
  }
}

/// `exclude_if_missing(expr)` and `expr` is `shape_name.column`.
fn exclude_if_missing_column_on_shape(
  left: glance.Expression,
  shape_name: String,
) -> Option(String) {
  case left {
    glance.Call(_, l_callee, l_args) ->
      case expression_callee_name(l_callee) {
        Ok("exclude_if_missing") ->
          case single_unlabelled_arg(l_args) {
            Some(inner) ->
              case field_access_root_and_leaf(inner) {
                Some(#(root, column)) if root == shape_name -> Some(column)
                _ -> None
              }
            None -> None
          }
        _ -> None
      }
    _ -> None
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

/// Extracts canonical `shape`/`filter`/`order` expressions from
/// a query pipeline (`query |> shape |> filter |> order`).
fn query_tail_components(
  expr: glance.Expression,
) -> Option(#(glance.Expression, glance.Expression, glance.Expression)) {
  case query_pipeline_components_desugared(expr) {
    Some(parts) -> Some(parts)
    None -> query_pipeline_components_pipe(expr)
  }
}

/// If `expr` is (after normalisation) `order(filter(shape(query(entity), shape), filter), order)`,
/// returns synthetic labelled fields compatible with query inference.
fn query_pipeline_components_desugared(
  expr: glance.Expression,
) -> Option(#(glance.Expression, glance.Expression, glance.Expression)) {
  case normalize_expr(expr) {
    glance.Call(_, order_callee, order_args) ->
      case expression_callee_name(order_callee) {
        Ok("order") ->
          case two_unlabelled_args(order_args) {
            Some(#(filter_expr, order_expr)) ->
              case normalize_expr(filter_expr) {
                glance.Call(_, filter_callee, filter_args) ->
                  case expression_callee_name(filter_callee) {
                    Ok("filter") ->
                      case two_unlabelled_args(filter_args) {
                        Some(#(shape_expr, filter_value_expr)) ->
                          case normalize_expr(shape_expr) {
                            glance.Call(_, shape_callee, shape_args) ->
                              case expression_callee_name(shape_callee) {
                                Ok("shape") ->
                                  case two_unlabelled_args(shape_args) {
                                    Some(#(query_expr, shape_value_expr)) ->
                                      case normalize_expr(query_expr) {
                                        glance.Call(_, query_callee, query_args) ->
                                          case
                                            expression_callee_name(query_callee)
                                          {
                                            Ok("query") ->
                                              case
                                                single_unlabelled_arg(
                                                  query_args,
                                                )
                                              {
                                                Some(_entity_expr) ->
                                                  Some(#(
                                                    shape_value_expr,
                                                    filter_value_expr,
                                                    order_expr,
                                                  ))
                                                None -> None
                                              }
                                            _ -> None
                                          }
                                        _ -> None
                                      }
                                    None -> None
                                  }
                                _ -> None
                              }
                            _ -> None
                          }
                        None -> None
                      }
                    _ -> None
                  }
                _ -> None
              }
            None -> None
          }
        _ -> None
      }
    _ -> None
  }
}

/// If `expr` preserves `|>` in the AST, match:
/// `query(entity) |> shape(shape) |> filter(filter) |> order(order)`.
fn query_pipeline_components_pipe(
  expr: glance.Expression,
) -> Option(#(glance.Expression, glance.Expression, glance.Expression)) {
  case normalize_expr(expr) {
    glance.BinaryOperator(_, _op3, left2, order_step) -> {
      use order_expr <- then(single_named_call_arg(order_step, "order"))
      case normalize_expr(left2) {
        glance.BinaryOperator(_, _op2, left1, filter_step) -> {
          use filter_expr <- then(single_named_call_arg(filter_step, "filter"))
          case normalize_expr(left1) {
            glance.BinaryOperator(_, _op1, query_step, shape_step) -> {
              use shape_expr <- then(single_named_call_arg(shape_step, "shape"))
              case normalize_expr(query_step) {
                glance.Call(_, query_callee, query_args) ->
                  case expression_callee_name(query_callee) {
                    Ok("query") ->
                      case single_unlabelled_arg(query_args) {
                        Some(_entity_expr) ->
                          Some(#(shape_expr, filter_expr, order_expr))
                        None -> None
                      }
                    _ -> None
                  }
                _ -> None
              }
            }
            _ -> None
          }
        }
        _ -> None
      }
    }
    _ -> None
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

/// Succeeds when the expression is (possibly inside a block) a simple variable — e.g. `shape` in `shape: hippo`.
fn expect_variable_name(expr: glance.Expression) -> Option(String) {
  case normalize_expr(expr) {
    glance.Variable(_, name) -> Some(name)
    _ -> None
  }
}

/// If `expr` is `Some(x)` (one argument), returns `x`; matches optional filter payload shape.
fn unwrap_some_call(expr: glance.Expression) -> Option(glance.Expression) {
  case normalize_expr(expr) {
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Ok("Some") ->
          case args {
            [glance.UnlabelledField(inner)] -> Some(inner)
            [glance.LabelledField(_, _, inner)] -> Some(inner)
            _ -> None
          }
        _ -> None
      }
    _ -> None
  }
}

/// Inside `filter: Some(…)`: unwraps `Predicate(value: …)` or unadorned `Predicate(…)`; otherwise returns the
/// inner expression unchanged (legacy `Some(expr)` style).
fn unwrap_predicate_filter_value(
  expr: glance.Expression,
) -> Option(glance.Expression) {
  case normalize_expr(expr) {
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Ok("Predicate") ->
          case args {
            [glance.UnlabelledField(inner)] -> Some(inner)
            [glance.LabelledField(label, _, inner)] if label == "value" ->
              Some(inner)
            _ -> None
          }
        _ -> Some(expr)
      }
    _ -> Some(expr)
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

/// For `a.b.c`, returns `#(a, c)` when the root is a variable name; middle segments are ignored.
fn field_access_root_and_leaf(
  expr: glance.Expression,
) -> Option(#(String, String)) {
  case normalize_expr(expr) {
    glance.FieldAccess(_, inner, label) ->
      case normalize_expr(inner) {
        glance.Variable(_, root) -> Some(#(root, label))
        inner2 ->
          case field_access_root_and_leaf(inner2) {
            Some(#(root, _middle)) -> Some(#(root, label))
            None -> None
          }
      }
    _ -> None
  }
}

/// Parses `order_by(shape.field, Asc)` and returns `field` when it belongs to `shape_name`.
fn query_order_column(
  order_expr: glance.Expression,
  shape_name: String,
) -> Result(String, Nil) {
  case normalize_expr(order_expr) {
    glance.Call(_, callee, oargs) ->
      case expression_callee_name(callee) {
        Ok("order_by") ->
          case oargs {
            [glance.UnlabelledField(field_ex), glance.UnlabelledField(dir_ex)] ->
              case is_asc_direction(dir_ex) {
                True ->
                  case field_access_root_and_leaf(field_ex) {
                    Some(#(root, col)) if root == shape_name -> Ok(col)
                    _ -> Error(Nil)
                  }
                False -> Error(Nil)
              }
            _ -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

/// Accepts `Asc` as a variable or qualified access (e.g. module-qualified).
fn is_asc_direction(expr: glance.Expression) -> Bool {
  case normalize_expr(expr) {
    glance.FieldAccess(_, _, "Asc") -> True
    glance.Variable(_, "Asc") -> True
    _ -> False
  }
}

/// True when `f` declares a parameter named `name` annotated as plain `Float`.
fn param_is_float_named(f: glance.Function, name: String) -> Bool {
  list.any(f.parameters, fn(p) {
    assignment_name_string(p.name) == name
    && case p.type_ {
      Some(glance.NamedType(_, "Float", None, [])) -> True
      _ -> False
    }
  })
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
/// They are not emitted as `QuerySpecDefinition`; use an explicit `-> ... BooleanFilter` annotation.
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
  case expr {
    glance.Call(_, callee, _) -> callee_is_order(callee)
    glance.Block(_, stmts) -> statements_return_query(stmts)
    _ -> False
  }
}

fn callee_is_order(expr: glance.Expression) -> Bool {
  case expression_callee_name(expr) {
    Ok("order") -> True
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

fn find_lt_missing_predicate_in_statements(
  body: List(glance.Statement),
  shape_name: String,
) -> Option(#(String, String)) {
  case body {
    [] -> None
    [stmt, ..rest] ->
      case find_lt_missing_predicate_in_statement(stmt, shape_name) {
        Some(v) -> Some(v)
        None -> find_lt_missing_predicate_in_statements(rest, shape_name)
      }
  }
}

fn find_lt_missing_predicate_in_statement(
  stmt: glance.Statement,
  shape_name: String,
) -> Option(#(String, String)) {
  case stmt {
    glance.Expression(e) -> find_lt_missing_predicate_in_expr(e, shape_name)
    _ -> None
  }
}

fn find_lt_missing_predicate_in_expr(
  expr: glance.Expression,
  shape_name: String,
) -> Option(#(String, String)) {
  case normalize_expr(expr) {
    glance.BinaryOperator(
      _,
      glance.LtFloat,
      left,
      glance.Variable(_, threshold_name),
    ) ->
      case exclude_if_missing_column_on_shape(left, shape_name) {
        Some(column) -> Some(#(column, threshold_name))
        None -> None
      }
    glance.BinaryOperator(_, _, left, right) ->
      case find_lt_missing_predicate_in_expr(left, shape_name) {
        Some(v) -> Some(v)
        None -> find_lt_missing_predicate_in_expr(right, shape_name)
      }
    glance.Call(_, _callee, args) ->
      find_lt_missing_predicate_in_fields(args, shape_name)
    glance.FieldAccess(_, inner, _) ->
      find_lt_missing_predicate_in_expr(inner, shape_name)
    glance.Block(_, stmts) ->
      find_lt_missing_predicate_in_statements(stmts, shape_name)
    _ -> None
  }
}

fn find_lt_missing_predicate_in_fields(
  fields: List(glance.Field(glance.Expression)),
  shape_name: String,
) -> Option(#(String, String)) {
  case fields {
    [] -> None
    [field, ..rest] ->
      case field {
        glance.UnlabelledField(e) ->
          case find_lt_missing_predicate_in_expr(e, shape_name) {
            Some(v) -> Some(v)
            None -> find_lt_missing_predicate_in_fields(rest, shape_name)
          }
        glance.LabelledField(_, _, e) ->
          case find_lt_missing_predicate_in_expr(e, shape_name) {
            Some(v) -> Some(v)
            None -> find_lt_missing_predicate_in_fields(rest, shape_name)
          }
        glance.ShorthandField(_, _) ->
          find_lt_missing_predicate_in_fields(rest, shape_name)
      }
  }
}

fn find_order_by_column_in_statements(
  body: List(glance.Statement),
  shape_name: String,
) -> Option(String) {
  case body {
    [] -> None
    [stmt, ..rest] ->
      case find_order_by_column_in_statement(stmt, shape_name) {
        Some(v) -> Some(v)
        None -> find_order_by_column_in_statements(rest, shape_name)
      }
  }
}

fn find_order_by_column_in_statement(
  stmt: glance.Statement,
  shape_name: String,
) -> Option(String) {
  case stmt {
    glance.Expression(e) -> find_order_by_column_in_expr(e, shape_name)
    _ -> None
  }
}

fn find_order_by_column_in_expr(
  expr: glance.Expression,
  shape_name: String,
) -> Option(String) {
  case normalize_expr(expr) {
    glance.Call(_, _callee, _) ->
      case from_result(query_order_column(expr, shape_name)) {
        Some(col) -> Some(col)
        None ->
          case normalize_expr(expr) {
            glance.Call(_, _c, args) ->
              find_order_by_column_in_fields(args, shape_name)
            _ -> None
          }
      }
    glance.BinaryOperator(_, _, left, right) ->
      case find_order_by_column_in_expr(left, shape_name) {
        Some(v) -> Some(v)
        None -> find_order_by_column_in_expr(right, shape_name)
      }
    glance.FieldAccess(_, inner, _) ->
      find_order_by_column_in_expr(inner, shape_name)
    glance.Block(_, stmts) ->
      find_order_by_column_in_statements(stmts, shape_name)
    _ -> None
  }
}

fn find_order_by_column_in_fields(
  fields: List(glance.Field(glance.Expression)),
  shape_name: String,
) -> Option(String) {
  case fields {
    [] -> None
    [field, ..rest] ->
      case field {
        glance.UnlabelledField(e) ->
          case find_order_by_column_in_expr(e, shape_name) {
            Some(v) -> Some(v)
            None -> find_order_by_column_in_fields(rest, shape_name)
          }
        glance.LabelledField(_, _, e) ->
          case find_order_by_column_in_expr(e, shape_name) {
            Some(v) -> Some(v)
            None -> find_order_by_column_in_fields(rest, shape_name)
          }
        glance.ShorthandField(_, _) ->
          find_order_by_column_in_fields(rest, shape_name)
      }
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

/// Public `BooleanFilter` helpers must start with `filter_`.
fn function_has_filter_prefix(name: String) -> Bool {
  string.starts_with(name, "filter_")
}
