//// Parses a `predicate_*` `glance.Function` into a `ComplexFilterPredicateSpec` IR.
////
//// Expected source shape:
////
//// ```gleam
//// pub fn predicate_<name>(
////   <root_param>: <RootEntityType>,
////   <leaf_param>: <LeafScalarType>,
//// ) -> dsl.BooleanFilter(dsl.BelongsTo(<TargetType>, <EdgeAttribsType>)) {
////   case <leaf_param> {
////     Constructor1(field1: f1) ->
////       dsl.any(<root_param>.relationships.<rel_field>, fn(p1, p2, p3, p4) { body })
////     Constructor2(...) -> ...
////   }
//// }
//// ```
////
//// All arms must reference the same relationship field; the parser verifies this
//// and records it once on the `ComplexFilterPredicateSpec`.

import generators/api/complex_filter_ir.{
  type BoolSubExpr, type BoundField, type ComplexFilterPredicateSpec,
  type EdgeMissingBehavior, type PredicateArm, type SubLeaf, type SubOperator,
  BoundField, BoundParam, ComplexFilterPredicateSpec, EdgeAttribAccess,
  EdgeMagicAccess, ExcludeIfMissing, LiteralBool, LiteralFloat, LiteralInt,
  LiteralString, Nullable, PredicateArm, SubAnd, SubCompare, SubEq, SubGe, SubGt,
  SubLe, SubLt, SubNe, SubNot, SubOr, TargetMagicAccess,
}
import glance
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import schema_definition/schema_definition.{type ParseError, UnsupportedSchema}

// =============================================================================
// Public entry point
// =============================================================================

/// Parse one `predicate_*` function into a `ComplexFilterPredicateSpec`.
pub fn parse(
  f: glance.Function,
) -> Result(ComplexFilterPredicateSpec, ParseError) {
  use #(root_param_name, root_entity_type) <- result.try(extract_root_param(f))
  use #(leaf_param_name, leaf_param_type) <- result.try(extract_leaf_param(f))
  use #(target_entity_type, edge_attribs_type) <- result.try(
    extract_return_types(f),
  )
  use case_expr <- result.try(extract_case_body(f, leaf_param_name))
  use #(relationship_field, arms) <- result.try(parse_case_arms(
    f,
    case_expr,
    root_param_name,
    leaf_param_name,
  ))
  Ok(ComplexFilterPredicateSpec(
    fn_name: f.name,
    root_param_name: root_param_name,
    root_entity_type: root_entity_type,
    leaf_param_name: leaf_param_name,
    leaf_param_type: leaf_param_type,
    relationship_field: relationship_field,
    target_entity_type: target_entity_type,
    edge_attribs_type: edge_attribs_type,
    arms: arms,
  ))
}

// =============================================================================
// Parameter extraction
// =============================================================================

fn extract_root_param(
  f: glance.Function,
) -> Result(#(String, String), ParseError) {
  case f.parameters {
    [first, ..] ->
      case first.type_ {
        Some(glance.NamedType(_, type_name, None, [])) ->
          Ok(#(param_name_string(first.name), type_name))
        Some(_) ->
          err(
            f,
            "first parameter of " <> f.name <> " must be a plain entity type",
          )
        None ->
          err(
            f,
            "first parameter of " <> f.name <> " must have a type annotation",
          )
      }
    [] -> err(f, f.name <> " must have at least two parameters")
  }
}

fn extract_leaf_param(
  f: glance.Function,
) -> Result(#(String, String), ParseError) {
  case f.parameters {
    [_, second, ..] ->
      case second.type_ {
        Some(glance.NamedType(_, type_name, None, [])) ->
          Ok(#(param_name_string(second.name), type_name))
        Some(_) ->
          err(
            f,
            "second parameter of " <> f.name <> " must be a plain scalar type",
          )
        None ->
          err(
            f,
            "second parameter of " <> f.name <> " must have a type annotation",
          )
      }
    _ -> err(f, f.name <> " must have exactly two parameters")
  }
}

/// Return annotation: `BooleanFilter(BelongsTo(TargetType, EdgeType))`.
fn extract_return_types(
  f: glance.Function,
) -> Result(#(String, String), ParseError) {
  case f.return {
    None ->
      err(
        f,
        f.name
          <> " must have an explicit return annotation `dsl.BooleanFilter(dsl.BelongsTo(TargetType, EdgeType))`",
      )
    Some(t) ->
      case unwrap_boolean_filter(t) {
        Some(inner) ->
          case unwrap_belongs_to(inner) {
            Some(#(target, edge)) -> Ok(#(target, edge))
            None ->
              err(
                f,
                f.name
                  <> " return type must be `BooleanFilter(BelongsTo(TargetType, EdgeType))`",
              )
          }
        None ->
          err(
            f,
            f.name <> " return type must be `BooleanFilter(BelongsTo(...))`",
          )
      }
  }
}

fn unwrap_boolean_filter(t: glance.Type) -> Option(glance.Type) {
  case t {
    glance.NamedType(_, "BooleanFilter", _, [inner]) -> Some(inner)
    _ -> None
  }
}

fn unwrap_belongs_to(t: glance.Type) -> Option(#(String, String)) {
  case t {
    glance.NamedType(
      _,
      "BelongsTo",
      _,
      [
        glance.NamedType(_, target_name, _, []),
        glance.NamedType(_, edge_name, _, []),
      ],
    ) -> Some(#(target_name, edge_name))
    _ -> None
  }
}

// =============================================================================
// Body: `case leaf_param { ... }`
// =============================================================================

fn extract_case_body(
  f: glance.Function,
  leaf_param_name: String,
) -> Result(glance.Expression, ParseError) {
  case tail_expression(f.body) {
    None ->
      err(
        f,
        f.name <> " body must be a single `case` expression on the leaf param",
      )
    Some(expr) ->
      case normalize(expr) {
        glance.Case(_, [subject], _clauses) ->
          case normalize(subject) {
            glance.Variable(_, name) if name == leaf_param_name -> Ok(expr)
            _ ->
              err(
                f,
                f.name <> " case subject must be `" <> leaf_param_name <> "`",
              )
          }
        _ ->
          err(
            f,
            f.name <> " body must be `case " <> leaf_param_name <> " { ... }`",
          )
      }
  }
}

// =============================================================================
// Case arms — returns shared relationship field + parsed arms
// =============================================================================

/// Parse all case arms.  All arms must use the same `root.relationships.<field>` path.
fn parse_case_arms(
  f: glance.Function,
  case_expr: glance.Expression,
  root_param_name: String,
  _leaf_param_name: String,
) -> Result(#(String, List(PredicateArm)), ParseError) {
  case normalize(case_expr) {
    glance.Case(_, _, clauses) ->
      case clauses {
        [] -> err(f, f.name <> " case must have at least one arm")
        _ ->
          list.try_fold(clauses, #("", []), fn(acc, clause) {
            let #(seen_rel_field, arms_so_far) = acc
            use #(rel_field, arm) <- result.try(parse_arm(
              f,
              clause,
              root_param_name,
            ))
            case seen_rel_field == "" || seen_rel_field == rel_field {
              True -> Ok(#(rel_field, list.append(arms_so_far, [arm])))
              False ->
                err(
                  f,
                  f.name
                    <> " all arms must use the same relationship field (got `"
                    <> seen_rel_field
                    <> "` and `"
                    <> rel_field
                    <> "`)",
                )
            }
          })
      }
    _ -> err(f, f.name <> " body is not a case expression")
  }
}

// =============================================================================
// Single arm: `Constructor(...) -> dsl.any(...)`
// =============================================================================

/// Returns `#(relationship_field, arm)`.
fn parse_arm(
  f: glance.Function,
  clause: glance.Clause,
  root_param_name: String,
) -> Result(#(String, PredicateArm), ParseError) {
  let glance.Clause(patterns: patterns, guard: _guard, body: body_expr) = clause
  use #(constructor_name, bound_fields) <- result.try(parse_constructor_pattern(
    f,
    patterns,
  ))
  use
    #(
      rel_field,
      target_param,
      target_magic_param,
      edge_attribs_param,
      edge_magic_param,
      body_sub_expr,
    )
  <- result.try(parse_any_call(
    f,
    normalize(body_expr),
    root_param_name,
    bound_fields,
  ))
  Ok(#(
    rel_field,
    PredicateArm(
      constructor_name: constructor_name,
      bound_fields: bound_fields,
      target_lambda_param: target_param,
      target_magic_param: target_magic_param,
      edge_attribs_param: edge_attribs_param,
      edge_magic_param: edge_magic_param,
      body: body_sub_expr,
    ),
  ))
}

fn parse_constructor_pattern(
  f: glance.Function,
  patterns: List(List(glance.Pattern)),
) -> Result(#(String, List(BoundField)), ParseError) {
  case patterns {
    [[single_pattern]] ->
      case single_pattern {
        glance.PatternVariant(_, _module, constructor_name, fields, _spread) -> {
          use bound <- result.try(
            list.try_map(fields, fn(field) { parse_bound_field(f, field) }),
          )
          Ok(#(constructor_name, bound))
        }
        _ ->
          err(
            f,
            f.name
              <> " each arm pattern must be a constructor like `Has(tag_id: tag_id)`",
          )
      }
    _ -> err(f, f.name <> " each arm must have exactly one pattern")
  }
}

fn parse_bound_field(
  f: glance.Function,
  field: glance.Field(glance.Pattern),
) -> Result(BoundField, ParseError) {
  case field {
    glance.LabelledField(label: label, item: glance.PatternVariable(_, _), ..) ->
      Ok(BoundField(name: label, type_: placeholder_int_type()))
    glance.UnlabelledField(item: glance.PatternVariable(_, var_name)) ->
      Ok(BoundField(name: var_name, type_: placeholder_int_type()))
    glance.LabelledField(label: label, item: glance.PatternDiscard(_, _), ..) ->
      Ok(BoundField(name: label, type_: placeholder_int_type()))
    glance.UnlabelledField(item: glance.PatternDiscard(_, _)) ->
      err(
        f,
        f.name
          <> " unlabelled discards in constructor patterns are not supported",
      )
    glance.ShorthandField(label: label, ..) ->
      Ok(BoundField(name: label, type_: placeholder_int_type()))
    _ ->
      err(
        f,
        f.name <> " constructor field must be a labelled variable or discard",
      )
  }
}

/// Placeholder type for bound fields.  The code generator refines this from the
/// leaf scalar type definition before emitting bind expressions.
fn placeholder_int_type() -> glance.Type {
  glance.NamedType(glance.Span(0, 0), "Int", None, [])
}

// =============================================================================
// dsl.any(root.relationships.field, fn(p1,p2,p3,p4) { body })
// =============================================================================

fn parse_any_call(
  f: glance.Function,
  expr: glance.Expression,
  root_param_name: String,
  bound_fields: List(BoundField),
) -> Result(#(String, String, String, String, String, BoolSubExpr), ParseError) {
  case expr {
    glance.Call(_, callee, args) ->
      case expression_callee_name(callee) {
        Some("any") ->
          case args {
            [
              glance.UnlabelledField(path_expr),
              glance.UnlabelledField(glance.Fn(_, fn_params, _, fn_body)),
            ] -> {
              use rel_field <- result.try(parse_relationship_path(
                f,
                path_expr,
                root_param_name,
              ))
              use #(p1, p2, p3, p4) <- result.try(parse_four_lambda_params(
                f,
                fn_params,
              ))
              let bound_names = list.map(bound_fields, fn(bf) { bf.name })
              use body <- result.try(parse_bool_body(
                f,
                tail_expression(fn_body),
                p2,
                p3,
                p4,
                bound_names,
              ))
              Ok(#(rel_field, p1, p2, p3, p4, body))
            }
            _ ->
              err(
                f,
                f.name
                  <> " arm must be `dsl.any(root.relationships.field, fn(p1, p2, p3, p4) { ... })`",
              )
          }
        _ -> err(f, f.name <> " arm body must call `dsl.any(...)`")
      }
    _ -> err(f, f.name <> " arm body must be a `dsl.any(...)` call")
  }
}

fn parse_relationship_path(
  f: glance.Function,
  expr: glance.Expression,
  root_param_name: String,
) -> Result(String, ParseError) {
  case normalize(expr) {
    glance.FieldAccess(
      _,
      glance.FieldAccess(_, glance.Variable(_, root_name), "relationships"),
      field_name,
    )
      if root_name == root_param_name
    -> Ok(field_name)
    _ ->
      err(
        f,
        f.name
          <> " `dsl.any` first argument must be `"
          <> root_param_name
          <> ".relationships.<field>`",
      )
  }
}

fn parse_four_lambda_params(
  f: glance.Function,
  params: List(glance.FnParameter),
) -> Result(#(String, String, String, String), ParseError) {
  case params {
    [p1, p2, p3, p4] ->
      Ok(#(
        fn_param_name(p1),
        fn_param_name(p2),
        fn_param_name(p3),
        fn_param_name(p4),
      ))
    _ ->
      err(
        f,
        f.name
          <> " `dsl.any` lambda must have exactly 4 parameters: (target, target_magic, edge_attribs, edge_magic)",
      )
  }
}

fn fn_param_name(p: glance.FnParameter) -> String {
  case p.name {
    glance.Named(s) -> s
    glance.Discarded(s) -> s
  }
}

// =============================================================================
// Boolean sublanguage
// =============================================================================

fn parse_bool_body(
  f: glance.Function,
  maybe_expr: Option(glance.Expression),
  target_magic_param: String,
  edge_attribs_param: String,
  edge_magic_param: String,
  bound_names: List(String),
) -> Result(BoolSubExpr, ParseError) {
  case maybe_expr {
    None -> err(f, f.name <> " lambda body must not be empty")
    Some(expr) ->
      parse_sub_expr(
        f,
        normalize(expr),
        target_magic_param,
        edge_attribs_param,
        edge_magic_param,
        bound_names,
      )
  }
}

fn parse_sub_expr(
  f: glance.Function,
  expr: glance.Expression,
  target_magic_param: String,
  edge_attribs_param: String,
  edge_magic_param: String,
  bound_names: List(String),
) -> Result(BoolSubExpr, ParseError) {
  let recurse = fn(e) {
    parse_sub_expr(
      f,
      normalize(e),
      target_magic_param,
      edge_attribs_param,
      edge_magic_param,
      bound_names,
    )
  }
  let leaf = fn(e) {
    parse_leaf(
      f,
      normalize(e),
      target_magic_param,
      edge_attribs_param,
      edge_magic_param,
      bound_names,
    )
  }
  case expr {
    glance.BinaryOperator(_, glance.And, left, right) -> {
      use l <- result.try(recurse(left))
      use r <- result.try(recurse(right))
      Ok(SubAnd(flatten_and([l, r])))
    }
    glance.BinaryOperator(_, glance.Or, left, right) -> {
      use l <- result.try(recurse(left))
      use r <- result.try(recurse(right))
      Ok(SubOr(flatten_or([l, r])))
    }
    glance.NegateBool(_, inner) -> {
      use i <- result.try(recurse(inner))
      Ok(SubNot(i))
    }
    glance.BinaryOperator(_, op, left, right) -> {
      use sub_op <- result.try(sub_operator(f, op))
      use l_leaf <- result.try(leaf(left))
      use r_leaf <- result.try(leaf(right))
      Ok(SubCompare(left: l_leaf, operator: sub_op, right: r_leaf))
    }
    _ ->
      err(
        f,
        f.name
          <> " lambda body contains an unsupported expression (expected &&, ||, !, or a comparison)",
      )
  }
}

fn flatten_and(items: List(BoolSubExpr)) -> List(BoolSubExpr) {
  list.flat_map(items, fn(item) {
    case item {
      SubAnd(inner) -> flatten_and(inner)
      other -> [other]
    }
  })
}

fn flatten_or(items: List(BoolSubExpr)) -> List(BoolSubExpr) {
  list.flat_map(items, fn(item) {
    case item {
      SubOr(inner) -> flatten_or(inner)
      other -> [other]
    }
  })
}

fn sub_operator(
  f: glance.Function,
  op: glance.BinaryOperator,
) -> Result(SubOperator, ParseError) {
  case op {
    glance.Eq -> Ok(SubEq)
    glance.NotEq -> Ok(SubNe)
    glance.LtInt | glance.LtFloat -> Ok(SubLt)
    glance.GtInt | glance.GtFloat -> Ok(SubGt)
    glance.LtEqInt | glance.LtEqFloat -> Ok(SubLe)
    glance.GtEqInt | glance.GtEqFloat -> Ok(SubGe)
    _ ->
      err(f, f.name <> " lambda body uses an unsupported comparison operator")
  }
}

// =============================================================================
// Leaf values
// =============================================================================

fn parse_leaf(
  f: glance.Function,
  expr: glance.Expression,
  target_magic_param: String,
  edge_attribs_param: String,
  edge_magic_param: String,
  bound_names: List(String),
) -> Result(SubLeaf, ParseError) {
  case expr {
    // Boolean literals — must come before the generic `Variable` case.
    glance.Variable(_, "True") -> Ok(LiteralBool(True))
    glance.Variable(_, "False") -> Ok(LiteralBool(False))

    // `target_magic_param.field`
    glance.FieldAccess(_, glance.Variable(_, obj), field)
      if obj == target_magic_param
    -> Ok(TargetMagicAccess(field))

    // `edge_attribs_param.field`
    glance.FieldAccess(_, glance.Variable(_, obj), field)
      if obj == edge_attribs_param
    -> Ok(EdgeAttribAccess(field, None))

    // `edge_magic_param.field`
    glance.FieldAccess(_, glance.Variable(_, obj), field)
      if obj == edge_magic_param
    -> Ok(EdgeMagicAccess(field))

    // `dsl.exclude_if_missing(edge.field)` or `exclude_if_missing(edge.field)`
    glance.Call(_, callee, [glance.UnlabelledField(inner)]) ->
      case expression_callee_name(callee) {
        Some("exclude_if_missing") ->
          parse_missing_wrapped_leaf(
            f,
            normalize(inner),
            edge_attribs_param,
            ExcludeIfMissing,
          )
        Some("nullable") ->
          parse_missing_wrapped_leaf(
            f,
            normalize(inner),
            edge_attribs_param,
            Nullable,
          )
        _ ->
          err(
            f,
            f.name
              <> " leaf uses an unsupported function call (only `exclude_if_missing` and `nullable` are allowed)",
          )
      }

    // Bound constructor parameter
    glance.Variable(_, name) ->
      case list.contains(bound_names, name) {
        True -> Ok(BoundParam(name))
        False ->
          err(
            f,
            f.name
              <> " variable `"
              <> name
              <> "` is not a bound constructor field, a known parameter, or a literal",
          )
      }

    glance.Int(_, value_str) ->
      case int.parse(value_str) {
        Ok(n) -> Ok(LiteralInt(n))
        Error(_) ->
          err(f, f.name <> " invalid integer literal `" <> value_str <> "`")
      }

    glance.Float(_, value_str) ->
      case float.parse(value_str) {
        Ok(n) -> Ok(LiteralFloat(n))
        Error(_) ->
          err(f, f.name <> " invalid float literal `" <> value_str <> "`")
      }

    glance.String(_, value) -> Ok(LiteralString(value))

    _ ->
      err(
        f,
        f.name
          <> " leaf expression is not a recognized form (`magic.field`, `edge.field`, `exclude_if_missing(edge.field)`, a bound param, or a literal)",
      )
  }
}

fn parse_missing_wrapped_leaf(
  f: glance.Function,
  inner: glance.Expression,
  edge_attribs_param: String,
  behavior: EdgeMissingBehavior,
) -> Result(SubLeaf, ParseError) {
  case inner {
    glance.FieldAccess(_, glance.Variable(_, obj), field)
      if obj == edge_attribs_param
    -> Ok(EdgeAttribAccess(field, Some(behavior)))
    _ ->
      err(
        f,
        "argument to `exclude_if_missing` / `nullable` must be `"
          <> edge_attribs_param
          <> ".<field>`",
      )
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn tail_expression(body: List(glance.Statement)) -> Option(glance.Expression) {
  case list.last(body) {
    Ok(glance.Expression(e)) -> Some(e)
    _ -> None
  }
}

fn normalize(expr: glance.Expression) -> glance.Expression {
  case expr {
    glance.Block(_, stmts) ->
      case tail_expression(stmts) {
        Some(inner) -> normalize(inner)
        None -> expr
      }
    _ -> expr
  }
}

fn expression_callee_name(expr: glance.Expression) -> Option(String) {
  case expr {
    glance.Variable(_, name) -> Some(name)
    glance.FieldAccess(_, _, label) -> Some(label)
    _ -> None
  }
}

fn param_name_string(name: glance.AssignmentName) -> String {
  case name {
    glance.Named(s) -> s
    glance.Discarded(s) -> s
  }
}

fn err(f: glance.Function, message: String) -> Result(a, ParseError) {
  Error(UnsupportedSchema(Some(f.location), message))
}
