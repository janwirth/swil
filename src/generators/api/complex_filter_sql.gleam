//// Generates Gleam source code strings for `filter_complex` queries.
////
//// Given a `ComplexFilterPredicateSpec` (from `predicate_parser`) and schema context,
//// this module emits the Gleam functions included in the generated `query.gleam`.
////
//// ## Emitted functions per complex-filter query
////
//// 1. `<prefix>_filter_to_sql` — walks `dsl.BooleanFilter(LeafType)` → `#(String, List(sqlight.Value))`.
//// 2. `<prefix>_predicate_to_sql` — cases on each leaf constructor, returns EXISTS SQL + binds.
//// 3. `<query_name>_sql_with` — builds the full query SQL for a given filter tree.
//// 4. `query_<name>` (public) — takes `conn` + decoded filter, calls `sqlight.query`.
////
//// ## Naming conventions
////
//// - Junction table: `<root_lower>_<target_lower>`  e.g. `trackbucket_tag`.
//// - Root FK:        `<root_lower>_id`               e.g. `trackbucket_id`.
//// - Target FK:      `<target_lower>_id`             e.g. `tag_id`.
//// - Root table alias in SQL: `tb`;  junction alias: `rel`;  target alias: `t`.

import generators/api/complex_filter_ir.{
  type BoolSubExpr, type ComplexFilterPredicateSpec, type SubLeaf,
  type SubOperator, BoundParam, EdgeAttribAccess, EdgeMagicAccess, LiteralBool,
  LiteralFloat, LiteralInt, LiteralString, SubAnd, SubCompare, SubEq, SubGe,
  SubGt, SubLe, SubLt, SubNe, SubNot, SubOr, TargetMagicAccess,
}
import glance
import gleam/float
import gleam/int
import gleam/list
import gleam/string

// =============================================================================
// Context for one complex-filter query
// =============================================================================

pub type ComplexFilterGenCtx {
  ComplexFilterGenCtx(
    /// Gleam import alias for the schema module, e.g. `"library_manager_advanced_schema"`.
    schema_alias: String,
    /// Qualified type used in the query function signature, e.g.
    /// `"library_manager_advanced_schema.FilterExpressionScalar"`.
    filter_param_type: String,
    /// Qualified leaf scalar type, e.g.
    /// `"library_manager_advanced_schema.TagExpressionScalar"`.
    leaf_scalar_type: String,
    /// Row tuple type returned by the query, e.g.
    /// `"#(library_manager_advanced_schema.TrackBucket, dsl.MagicFields)"`.
    row_tuple_type: String,
    /// Decoder function name (unqualified), e.g. `"trackbucket_with_magic_row_decoder"`.
    row_decoder_fn: String,
    /// SQL SELECT column list (already quoted), e.g. `"\"title\", \"artist\", ..."`.
    select_cols_sql: String,
    /// Main entity table name (unquoted), e.g. `"trackbucket"`.
    root_table: String,
    /// Root alias in generated SQL, e.g. `"tb"`.
    root_alias: String,
    /// ORDER BY SQL fragment, e.g. `"tb.\"updated_at\" desc"`.
    order_sql: String,
    /// Snake-case prefix for helper function names, e.g. `"tag"`.
    filter_prefix: String,
  )
}

// =============================================================================
// Top-level emitter
// =============================================================================

/// Returns the Gleam source text for all four functions of one complex-filter query.
pub fn emit_complex_filter_query(
  spec: ComplexFilterPredicateSpec,
  ctx: ComplexFilterGenCtx,
  query_fn_name: String,
) -> String {
  let sql_with_fn = query_fn_name <> "_sql_with"
  let filter_to_sql_fn = ctx.filter_prefix <> "_filter_to_sql"
  let predicate_to_sql_fn = ctx.filter_prefix <> "_predicate_to_sql"
  let junction_table =
    string.lowercase(spec.root_entity_type)
    <> "_"
    <> string.lowercase(spec.target_entity_type)
  let root_fk_col = string.lowercase(spec.root_entity_type) <> "_id"
  let target_fk_col = string.lowercase(spec.target_entity_type) <> "_id"
  let target_table = string.lowercase(spec.target_entity_type)

  string.join(
    [
      emit_filter_to_sql_fn(
        filter_to_sql_fn,
        predicate_to_sql_fn,
        ctx.filter_param_type,
      ),
      emit_predicate_to_sql_fn(
        predicate_to_sql_fn,
        ctx.leaf_scalar_type,
        ctx.schema_alias,
        spec,
        junction_table,
        target_table,
        root_fk_col,
        target_fk_col,
      ),
      emit_sql_with_fn(sql_with_fn, filter_to_sql_fn, ctx),
      emit_public_query_fn(
        query_fn_name,
        sql_with_fn,
        ctx.filter_param_type,
        ctx.row_tuple_type,
        ctx.row_decoder_fn,
      ),
    ],
    "\n\n",
  )
}

// =============================================================================
// 1. filter_to_sql: walks the BooleanFilter tree
// =============================================================================

fn emit_filter_to_sql_fn(
  fn_name: String,
  predicate_fn: String,
  filter_type: String,
) -> String {
  "fn "
  <> fn_name
  <> "(\n"
  <> "  filter: "
  <> filter_type
  <> ",\n"
  <> "  root_alias: String,\n"
  <> ") -> #(String, List(sqlight.Value)) {\n"
  <> "  case filter {\n"
  <> "    dsl.And(exprs) -> {\n"
  <> "      let parts = list.map(exprs, fn(e) { "
  <> fn_name
  <> "(e, root_alias) })\n"
  <> "      let sqls = list.map(parts, fn(p) { p.0 })\n"
  <> "      let binds = list.flat_map(parts, fn(p) { p.1 })\n"
  <> "      #(string.join(sqls, \" and \"), binds)\n"
  <> "    }\n"
  <> "    dsl.Or(exprs) -> {\n"
  <> "      let parts = list.map(exprs, fn(e) { "
  <> fn_name
  <> "(e, root_alias) })\n"
  <> "      let sqls = list.map(parts, fn(p) { p.0 })\n"
  <> "      let binds = list.flat_map(parts, fn(p) { p.1 })\n"
  <> "      #(\"(\" <> string.join(sqls, \" or \") <> \")\", binds)\n"
  <> "    }\n"
  <> "    dsl.Not(expr) -> {\n"
  <> "      let #(inner_sql, binds) = "
  <> fn_name
  <> "(expr, root_alias)\n"
  <> "      #(\"not (\" <> inner_sql <> \")\", binds)\n"
  <> "    }\n"
  <> "    dsl.Predicate(leaf) -> "
  <> predicate_fn
  <> "(leaf, root_alias)\n"
  <> "  }\n"
  <> "}"
}

// =============================================================================
// 2. predicate_to_sql: one case arm per leaf constructor
// =============================================================================

fn emit_predicate_to_sql_fn(
  fn_name: String,
  leaf_type: String,
  schema_alias: String,
  spec: ComplexFilterPredicateSpec,
  junction_table: String,
  target_table: String,
  root_fk_col: String,
  target_fk_col: String,
) -> String {
  let arms =
    list.map(spec.arms, fn(arm) {
      emit_predicate_arm(
        arm,
        schema_alias,
        junction_table,
        target_table,
        root_fk_col,
        target_fk_col,
      )
    })
    |> string.join("\n")
  "fn "
  <> fn_name
  <> "(\n"
  <> "  leaf: "
  <> leaf_type
  <> ",\n"
  <> "  root_alias: String,\n"
  <> ") -> #(String, List(sqlight.Value)) {\n"
  <> "  case leaf {\n"
  <> arms
  <> "\n  }\n"
  <> "}"
}

fn emit_predicate_arm(
  arm: complex_filter_ir.PredicateArm,
  schema_alias: String,
  junction_table: String,
  target_table: String,
  root_fk_col: String,
  target_fk_col: String,
) -> String {
  let pattern = emit_arm_pattern(arm, schema_alias)
  let #(where_suffix, bind_exprs) = arm_body_to_where_and_binds(arm)
  let binds_code = case bind_exprs {
    [] -> "[]"
    _ -> "[" <> string.join(bind_exprs, ", ") <> "]"
  }
  // The fixed EXISTS skeleton is:
  //   exists (select 1 from "junction" as rel
  //     join "target" as t on t."id" = rel."target_fk" and t."deleted_at" is null
  //     where rel."root_fk" = <root_alias>."id"
  //     <where_suffix>
  //   )
  let exists_prefix =
    "exists (select 1"
    <> " from \\\""
    <> junction_table
    <> "\\\" as rel"
    <> " join \\\""
    <> target_table
    <> "\\\" as t"
    <> " on t.\\\"id\\\" = rel.\\\""
    <> target_fk_col
    <> "\\\""
    <> " and t.\\\"deleted_at\\\" is null"
    <> " where rel.\\\""
    <> root_fk_col
    <> "\\\" = "
  "    "
  <> pattern
  <> " -> #(\n"
  <> "      \""
  <> exists_prefix
  <> "\" <> root_alias <> \".\\\"id\\\""
  <> where_suffix
  <> "\""
  <> " <> \")\""
  <> ",\n"
  <> "      "
  <> binds_code
  <> ",\n"
  <> "    )"
}

fn emit_arm_pattern(
  arm: complex_filter_ir.PredicateArm,
  schema_alias: String,
) -> String {
  let field_strs =
    list.map(arm.bound_fields, fn(bf) { bf.name <> ": " <> bf.name })
  let fields_part = case field_strs {
    [] -> ""
    _ -> "(" <> string.join(field_strs, ", ") <> ")"
  }
  schema_alias <> "." <> arm.constructor_name <> fields_part
}

// =============================================================================
// Body → WHERE clause suffix + bind expressions
// =============================================================================

/// Translate the arm's `BoolSubExpr` body into:
/// - `where_suffix`: SQL string fragment to append after the fixed EXISTS skeleton.
///   Each condition starts with ` and `.
/// - `bind_exprs`: Gleam code strings for each `?` placeholder, in order.
fn arm_body_to_where_and_binds(
  arm: complex_filter_ir.PredicateArm,
) -> #(String, List(String)) {
  body_to_parts(arm.body, arm)
}

fn body_to_parts(
  expr: BoolSubExpr,
  arm: complex_filter_ir.PredicateArm,
) -> #(String, List(String)) {
  case expr {
    SubAnd(items) -> {
      let parts = list.map(items, fn(e) { body_to_parts(e, arm) })
      let sqls = list.map(parts, fn(p) { p.0 })
      let binds = list.flat_map(parts, fn(p) { p.1 })
      #(string.join(sqls, ""), binds)
    }
    SubOr(items) -> {
      let parts = list.map(items, fn(e) { body_to_parts(e, arm) })
      let sqls = list.map(parts, fn(p) { p.0 })
      let binds = list.flat_map(parts, fn(p) { p.1 })
      #(" and (" <> string.join(sqls, " or ") <> ")", binds)
    }
    SubNot(inner) -> {
      let #(inner_sql, binds) = body_to_parts(inner, arm)
      #(" and not (" <> inner_sql <> ")", binds)
    }
    SubCompare(left: left, operator: op, right: right) -> {
      let #(left_sql, left_binds) = leaf_parts(left, arm)
      let #(right_sql, right_binds) = leaf_parts(right, arm)
      let op_sql = operator_sql(op)
      // Each compare contributes one ` and <left> <op> <right>` fragment.
      let sql = " and " <> left_sql <> " " <> op_sql <> " " <> right_sql
      #(sql, list.append(left_binds, right_binds))
    }
  }
}

fn leaf_parts(
  leaf: SubLeaf,
  arm: complex_filter_ir.PredicateArm,
) -> #(String, List(String)) {
  case leaf {
    // Target row magic fields → `t."field"`
    TargetMagicAccess(field) -> #("t.\\\"" <> field <> "\\\"", [])
    // Edge attribute column → `rel."field"` (NULL exclusion via 3VL)
    EdgeAttribAccess(field, _missing_behavior) -> #(
      "rel.\\\"" <> field <> "\\\"",
      [],
    )
    // Edge junction row magic fields → `rel."field"`
    EdgeMagicAccess(field) -> #("rel.\\\"" <> field <> "\\\"", [])
    // Bound constructor parameter → `?` placeholder + Gleam bind expression
    BoundParam(name) -> #("?", [bind_expr_for(name, arm)])
    LiteralInt(n) -> #(int.to_string(n), [])
    LiteralFloat(f) -> #(float.to_string(f), [])
    LiteralString(s) -> #("'" <> s <> "'", [])
    LiteralBool(True) -> #("1", [])
    LiteralBool(False) -> #("0", [])
  }
}

fn operator_sql(op: SubOperator) -> String {
  case op {
    SubEq -> "="
    SubNe -> "!="
    SubLt -> "<"
    SubGt -> ">"
    SubLe -> "<="
    SubGe -> ">="
  }
}

fn bind_expr_for(name: String, arm: complex_filter_ir.PredicateArm) -> String {
  case list.find(arm.bound_fields, fn(bf) { bf.name == name }) {
    Ok(bf) -> sqlight_bind_of(name, bf.type_)
    Error(_) -> "sqlight.text(\"unknown_" <> name <> "\")"
  }
}

fn sqlight_bind_of(name: String, t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Int", _, _) -> "sqlight.int(" <> name <> ")"
    glance.NamedType(_, "Float", _, _) -> "sqlight.float(" <> name <> ")"
    glance.NamedType(_, "Bool", _, _) ->
      "sqlight.int(case " <> name <> " { True -> 1 False -> 0 })"
    glance.NamedType(_, "String", _, _) -> "sqlight.text(" <> name <> ")"
    _ -> "sqlight.int(" <> name <> ")"
  }
}

// =============================================================================
// 3. sql_with: builds the full SQL string for one filter tree at runtime
// =============================================================================

fn emit_sql_with_fn(
  fn_name: String,
  filter_to_sql_fn: String,
  ctx: ComplexFilterGenCtx,
) -> String {
  let select_sql =
    "select "
    <> ctx.select_cols_sql
    <> " from \\\""
    <> ctx.root_table
    <> "\\\" as "
    <> ctx.root_alias
    <> " where "
    <> ctx.root_alias
    <> ".\\\"deleted_at\\\" is null and "
  let order_suffix = " order by " <> ctx.order_sql
  "fn "
  <> fn_name
  <> "(\n"
  <> "  filter: "
  <> ctx.filter_param_type
  <> ",\n"
  <> ") -> #(String, List(sqlight.Value)) {\n"
  <> "  let #(filter_sql, binds) = "
  <> filter_to_sql_fn
  <> "(filter, \""
  <> ctx.root_alias
  <> "\")\n"
  <> "  #(\""
  <> select_sql
  <> "\" <> filter_sql <> \""
  <> order_suffix
  <> "\", binds)\n"
  <> "}"
}

// =============================================================================
// 4. Public query function
// =============================================================================

fn emit_public_query_fn(
  fn_name: String,
  sql_with_fn: String,
  filter_type: String,
  row_tuple_type: String,
  row_decoder_fn: String,
) -> String {
  "pub fn "
  <> fn_name
  <> "(\n"
  <> "  conn: sqlight.Connection,\n"
  <> "  filter: "
  <> filter_type
  <> ",\n"
  <> ") -> Result(List("
  <> row_tuple_type
  <> "), sqlight.Error) {\n"
  <> "  let #(sql, binds) = "
  <> sql_with_fn
  <> "(filter)\n"
  <> "  sqlight.query(sql, on: conn, with: binds, expecting: row."
  <> row_decoder_fn
  <> "())\n"
  <> "}"
}

// =============================================================================
// JSON codec generation
// =============================================================================

/// Emit a Gleam source string for a JSON decoder for `BooleanFilter(LeafType)`.
pub fn emit_bool_filter_decoder(
  decoder_fn_name: String,
  leaf_decoder_fn_name: String,
  filter_type: String,
) -> String {
  "pub fn "
  <> decoder_fn_name
  <> "() -> decode.Decoder("
  <> filter_type
  <> ") {\n"
  <> "  bool_filter_decoder("
  <> leaf_decoder_fn_name
  <> "())\n"
  <> "}\n"
  <> "\n"
  <> "fn bool_filter_decoder(leaf_dec: decode.Decoder(a)) -> decode.Decoder(dsl.BooleanFilter(a)) {\n"
  <> "  decode.recursive(fn() { bool_filter_decoder_inner(leaf_dec) })\n"
  <> "}\n"
  <> "\n"
  <> "fn bool_filter_decoder_inner(leaf_dec: decode.Decoder(a)) -> decode.Decoder(dsl.BooleanFilter(a)) {\n"
  <> "  use tag <- decode.field(\"tag\", decode.string)\n"
  <> "  case tag {\n"
  <> "    \"And\" -> {\n"
  <> "      use exprs <- decode.field(\"exprs\", decode.list(bool_filter_decoder(leaf_dec)))\n"
  <> "      decode.success(dsl.And(exprs))\n"
  <> "    }\n"
  <> "    \"Or\" -> {\n"
  <> "      use exprs <- decode.field(\"exprs\", decode.list(bool_filter_decoder(leaf_dec)))\n"
  <> "      decode.success(dsl.Or(exprs))\n"
  <> "    }\n"
  <> "    \"Not\" -> {\n"
  <> "      use expr <- decode.field(\"expr\", bool_filter_decoder(leaf_dec))\n"
  <> "      decode.success(dsl.Not(expr))\n"
  <> "    }\n"
  <> "    \"Predicate\" -> {\n"
  <> "      use item <- decode.field(\"item\", leaf_dec)\n"
  <> "      decode.success(dsl.Predicate(item))\n"
  <> "    }\n"
  <> "    _ -> decode.failure(dsl.And([]), \"unknown BooleanFilter tag: \" <> tag)\n"
  <> "  }\n"
  <> "}\n"
}

/// Emit a JSON decoder for a closed leaf scalar type from the spec's arm list.
pub fn emit_leaf_scalar_decoder(
  decoder_fn_name: String,
  leaf_type: String,
  schema_alias: String,
  spec: ComplexFilterPredicateSpec,
) -> String {
  let arms =
    list.map(spec.arms, fn(arm) {
      let ctor = schema_alias <> "." <> arm.constructor_name
      let field_binds =
        list.map(arm.bound_fields, fn(bf) {
          "      use "
          <> bf.name
          <> " <- decode.field(\""
          <> bf.name
          <> "\", "
          <> decoder_for_glance_type(bf.type_)
          <> ")\n"
        })
        |> string.join("")
      let field_args =
        list.map(arm.bound_fields, fn(bf) { bf.name <> ": " <> bf.name })
      let ctor_call = case field_args {
        [] -> ctor
        _ -> ctor <> "(" <> string.join(field_args, ", ") <> ")"
      }
      "    \""
      <> arm.constructor_name
      <> "\" -> {\n"
      <> field_binds
      <> "      decode.success("
      <> ctor_call
      <> ")\n"
      <> "    }\n"
    })
    |> string.join("")
  // Fallback uses the first arm's constructor name as the dummy value.
  let fallback_ctor = case spec.arms {
    [first, ..] -> {
      let ctor = schema_alias <> "." <> first.constructor_name
      case first.bound_fields {
        [] -> ctor
        fields ->
          ctor
          <> "("
          <> string.join(
            list.map(fields, fn(bf) {
              bf.name <> ": " <> default_value_for_glance_type(bf.type_)
            }),
            ", ",
          )
          <> ")"
      }
    }
    [] -> schema_alias <> ".Unknown"
  }
  "pub fn "
  <> decoder_fn_name
  <> "() -> decode.Decoder("
  <> leaf_type
  <> ") {\n"
  <> "  use tag <- decode.field(\"tag\", decode.string)\n"
  <> "  case tag {\n"
  <> arms
  <> "    _ -> decode.failure("
  <> fallback_ctor
  <> ", \"unknown "
  <> spec.leaf_param_type
  <> " tag: \" <> tag)\n"
  <> "  }\n"
  <> "}"
}

fn decoder_for_glance_type(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Int", _, _) -> "decode.int"
    glance.NamedType(_, "Float", _, _) -> "decode.float"
    glance.NamedType(_, "Bool", _, _) -> "decode.bool"
    glance.NamedType(_, "String", _, _) -> "decode.string"
    _ -> "decode.int"
  }
}

fn default_value_for_glance_type(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "Int", _, _) -> "0"
    glance.NamedType(_, "Float", _, _) -> "0.0"
    glance.NamedType(_, "Bool", _, _) -> "False"
    glance.NamedType(_, "String", _, _) -> "\"\""
    _ -> "0"
  }
}
