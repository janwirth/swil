import glance
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}

/// Public function that returns `Query` (annotation or trailing `Query(...)`); parameters must be typed.
pub type QuerySpecDefinition {
  QuerySpecDefinition(name: String, parameters: List(QueryParameter))
}

pub type QueryParameter {
  QueryParameter(label: Option(String), name: String, type_: glance.Type)
}

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
              False ->
                Error(UnsupportedSchema(
                  Some(f.location),
                  "public function "
                    <> f.name
                    <> " must return a Query (annotation or trailing Query(...))",
                ))
              True ->
                case query_spec_from_function_strict(f) {
                  Ok(spec) -> Ok([spec, ..acc])
                  Error(e) -> Error(e)
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
  |> result.map(fn(params) { QuerySpecDefinition(f.name, list.reverse(params)) })
}

fn function_is_query_spec(f: glance.Function) -> Bool {
  case f.return {
    Some(t) -> type_is_query(t)
    None -> statements_return_query(f.body)
  }
}

fn type_is_query(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Query", _, _) -> True
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
