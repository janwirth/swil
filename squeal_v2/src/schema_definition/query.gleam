import glance
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
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

/// Public function that returns `Query` (annotation or trailing `Query(...)`); parameters must be typed.
pub type QuerySpecDefinition {
  QuerySpecDefinition(
    name: String,
    parameters: List(QueryParameter),
    codegen: QueryCodegen,
  )
}

pub type QueryParameter {
  QueryParameter(label: Option(String), name: String, type_: glance.Type)
}

/// Collects `Query` specs from public functions. Public `BooleanFilter` helpers (`-> … BooleanFilter`) are allowed and skipped.
pub fn extract_from_functions(
  functions: List(glance.Definition(glance.Function)),
) -> Result(List(QuerySpecDefinition), ParseError) {
  list.try_fold(functions, [], fn(acc, def) {
    case def {
      glance.Definition(_, f) ->
        case f.publicity {
          glance.Private -> Ok(acc)
          glance.Public ->
            case function_is_query_spec(f) {
              True ->
                case query_spec_from_function_strict(f) {
                  Ok(spec) -> Ok([spec, ..acc])
                  Error(e) -> Error(e)
                }
              False ->
                case function_is_boolean_filter_helper(f) {
                  True -> Ok(acc)
                  False ->
                    Error(UnsupportedSchema(
                      Some(f.location),
                      "public function "
                        <> f.name
                        <> " must return a Query (annotation or trailing Query(...)) "
                        <> "or BooleanFilter (annotation) for nested filter helpers",
                    ))
                }
            }
        }
    }
  })
  |> result.map(list.reverse)
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
  |> result.map(fn(params) {
    QuerySpecDefinition(f.name, list.reverse(params), infer_query_codegen(f))
  })
}

fn infer_query_codegen(f: glance.Function) -> QueryCodegen {
  case function_tail_expression(f.body) {
    None -> Unsupported
    Some(tail) ->
      case query_call_arguments(tail) {
        None -> Unsupported
        Some(qargs) ->
          case
            lookup_labelled(qargs, "shape"),
            lookup_labelled(qargs, "filter"),
            lookup_labelled(qargs, "order")
          {
            Ok(shape_expr), Ok(filter_expr), Ok(order_expr) ->
              infer_lt_missing_field_asc(f, shape_expr, filter_expr, order_expr)
            _, _, _ -> Unsupported
          }
      }
  }
}

fn infer_lt_missing_field_asc(
  f: glance.Function,
  shape_expr: glance.Expression,
  filter_expr: glance.Expression,
  order_expr: glance.Expression,
) -> QueryCodegen {
  case expect_variable_name(shape_expr) {
    None -> Unsupported
    Some(shape_name) ->
      case unwrap_some_call(filter_expr) {
        None -> Unsupported
        Some(pred) ->
          case pred {
            glance.BinaryOperator(_, glance.LtFloat, left, right) ->
              case right {
                glance.Variable(_, threshold_name) ->
                  case left {
                    glance.Call(_, l_callee, l_args) ->
                      case expression_callee_name(l_callee) {
                        Ok("exclude_if_missing") ->
                          case single_unlabelled_arg(l_args) {
                            None -> Unsupported
                            Some(inner) ->
                              case field_access_root_and_leaf(inner) {
                                None -> Unsupported
                                Some(#(root, column)) ->
                                  case root == shape_name {
                                    False -> Unsupported
                                    True ->
                                      case query_order_column(order_expr, shape_name) {
                                        Error(Nil) -> Unsupported
                                        Ok(order_col) ->
                                          case column == order_col {
                                            False -> Unsupported
                                            True ->
                                              case param_is_float_named(f, threshold_name) {
                                                False -> Unsupported
                                                True ->
                                                  LtMissingFieldAsc(
                                                    column,
                                                    threshold_name,
                                                    shape_name,
                                                  )
                                              }
                                          }
                                      }
                                  }
                              }
                          }
                        _ -> Unsupported
                      }
                    _ -> Unsupported
                  }
                _ -> Unsupported
              }
            _ -> Unsupported
          }
      }
  }
}

fn function_tail_expression(body: List(glance.Statement)) -> Option(glance.Expression) {
  case list.last(body) {
    Ok(glance.Expression(e)) -> Some(e)
    _ -> None
  }
}

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

fn query_call_arguments(expr: glance.Expression) -> Option(List(glance.Field(glance.Expression))) {
  case normalize_expr(expr) {
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Ok("Query") -> Some(args)
        _ -> None
      }
    _ -> None
  }
}

fn lookup_labelled(
  fields: List(glance.Field(glance.Expression)),
  want: String,
) -> Result(glance.Expression, Nil) {
  list.find_map(fields, fn(field) {
    case field {
      glance.LabelledField(label, _, item) if label == want -> Ok(item)
      _ -> Error(Nil)
    }
  })
}

fn expect_variable_name(expr: glance.Expression) -> Option(String) {
  case normalize_expr(expr) {
    glance.Variable(_, name) -> Some(name)
    _ -> None
  }
}

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

fn single_unlabelled_arg(
  args: List(glance.Field(glance.Expression)),
) -> Option(glance.Expression) {
  case args {
    [glance.UnlabelledField(e)] -> Some(e)
    _ -> None
  }
}

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

fn is_asc_direction(expr: glance.Expression) -> Bool {
  case normalize_expr(expr) {
    glance.FieldAccess(_, _, "Asc") -> True
    glance.Variable(_, "Asc") -> True
    _ -> False
  }
}

fn param_is_float_named(f: glance.Function, name: String) -> Bool {
  list.any(f.parameters, fn(p) {
    assignment_name_string(p.name) == name
    && case p.type_ {
      Some(glance.NamedType(_, "Float", None, [])) -> True
      _ -> False
    }
  })
}

fn function_is_query_spec(f: glance.Function) -> Bool {
  case f.return {
    Some(t) -> type_is_query(t)
    None -> statements_return_query(f.body)
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

fn type_is_query(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Query", _, _) -> True
    _ -> False
  }
}

fn type_is_boolean_filter(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "BooleanFilter", _, _) -> True
    _ -> False
  }
}

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

fn expression_is_query_in_tail(expr: glance.Expression) -> Bool {
  case expr {
    glance.Call(_, callee, _) -> callee_is_query(callee)
    glance.Block(_, stmts) -> statements_return_query(stmts)
    _ -> False
  }
}

fn callee_is_query(expr: glance.Expression) -> Bool {
  case expression_callee_name(expr) {
    Ok("Query") -> True
    _ -> False
  }
}

fn expression_callee_name(expr: glance.Expression) -> Result(String, Nil) {
  case expr {
    glance.Variable(_, name) -> Ok(name)
    glance.FieldAccess(_, _inner, label) -> Ok(label)
    _ -> Error(Nil)
  }
}

fn assignment_name_string(name: glance.AssignmentName) -> String {
  case name {
    glance.Named(s) -> s
    glance.Discarded(s) -> s
  }
}
