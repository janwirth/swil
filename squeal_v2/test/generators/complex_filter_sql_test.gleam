//// Unit tests for `generators/api/complex_filter_sql`.
////
//// Builds `ComplexFilterPredicateSpec` values directly (no file I/O) and
//// asserts on the generated Gleam source strings.

import generators/api/complex_filter_ir as ir
import generators/api/complex_filter_sql as csql
import glance
import gleam/option.{None, Some}
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// =============================================================================
// Helpers
// =============================================================================

fn int_type() -> glance.Type {
  glance.NamedType(glance.Span(0, 0), "Int", None, [])
}

/// Minimal single-arm spec matching:
///   Has(tag_id: tag_id) -> dsl.any(tb.relationships.tags, fn(_t, magic, _ea, _em) { magic.id == tag_id })
fn has_spec() -> ir.ComplexFilterPredicateSpec {
  let has_arm =
    ir.PredicateArm(
      constructor_name: "Has",
      bound_fields: [ir.BoundField(name: "tag_id", type_: int_type())],
      target_lambda_param: "_tag",
      target_magic_param: "magic_fields",
      edge_attribs_param: "_edge_attribs",
      edge_magic_param: "_edge_magic",
      body: ir.SubCompare(
        left: ir.TargetMagicAccess("id"),
        operator: ir.SubEq,
        right: ir.BoundParam("tag_id"),
      ),
    )
  ir.ComplexFilterPredicateSpec(
    fn_name: "predicate_complex_tags_filter",
    root_param_name: "track_bucket",
    root_entity_type: "TrackBucket",
    leaf_param_name: "tag_expression",
    leaf_param_type: "TagExpressionScalar",
    relationship_field: "tags",
    target_entity_type: "Tag",
    edge_attribs_type: "TrackBucketRelationshipAttributes",
    arms: [has_arm],
  )
}

/// Two-arm spec with Has and IsAtLeast.
fn two_arm_spec() -> ir.ComplexFilterPredicateSpec {
  let has_arm =
    ir.PredicateArm(
      constructor_name: "Has",
      bound_fields: [ir.BoundField(name: "tag_id", type_: int_type())],
      target_lambda_param: "_tag",
      target_magic_param: "magic_fields",
      edge_attribs_param: "_edge_attribs",
      edge_magic_param: "_edge_magic",
      body: ir.SubCompare(
        left: ir.TargetMagicAccess("id"),
        operator: ir.SubEq,
        right: ir.BoundParam("tag_id"),
      ),
    )
  let is_at_least_arm =
    ir.PredicateArm(
      constructor_name: "IsAtLeast",
      bound_fields: [
        ir.BoundField(name: "tag_id", type_: int_type()),
        ir.BoundField(name: "value", type_: int_type()),
      ],
      target_lambda_param: "_tag",
      target_magic_param: "magic_fields",
      edge_attribs_param: "edge_attribs",
      edge_magic_param: "_edge_magic",
      body: ir.SubAnd([
        ir.SubCompare(
          left: ir.TargetMagicAccess("id"),
          operator: ir.SubEq,
          right: ir.BoundParam("tag_id"),
        ),
        ir.SubCompare(
          left: ir.EdgeAttribAccess("value", Some(ir.ExcludeIfMissing)),
          operator: ir.SubGe,
          right: ir.BoundParam("value"),
        ),
      ]),
    )
  ir.ComplexFilterPredicateSpec(..has_spec(), arms: [has_arm, is_at_least_arm])
}

fn default_ctx() -> csql.ComplexFilterGenCtx {
  csql.ComplexFilterGenCtx(
    schema_alias: "schema",
    filter_param_type: "schema.FilterExpressionScalar",
    leaf_scalar_type: "schema.TagExpressionScalar",
    row_tuple_type: "#(schema.TrackBucket, dsl.MagicFields)",
    row_decoder_fn: "trackbucket_row_decoder",
    select_cols_sql: "\"title\", \"artist\"",
    root_table: "trackbucket",
    root_alias: "tb",
    order_sql: "tb.\"updated_at\" desc",
    filter_prefix: "tag",
  )
}

fn emit(spec: ir.ComplexFilterPredicateSpec) -> String {
  csql.emit_complex_filter_query(spec, default_ctx(), "query_tracks_by_filter")
}

// =============================================================================
// filter_to_sql function
// =============================================================================

pub fn filter_to_sql_fn_name_test() {
  let src = emit(has_spec())
  assert string.contains(src, "fn tag_filter_to_sql(")
}

pub fn filter_to_sql_handles_and_test() {
  let src = emit(has_spec())
  assert string.contains(src, "dsl.And(exprs)")
  assert string.contains(src, "string.join(sqls, \" and \")")
}

pub fn filter_to_sql_handles_or_test() {
  let src = emit(has_spec())
  assert string.contains(src, "dsl.Or(exprs)")
}

pub fn filter_to_sql_handles_not_test() {
  let src = emit(has_spec())
  assert string.contains(src, "dsl.Not(expr)")
  assert string.contains(src, "\"not (\"")
}

pub fn filter_to_sql_delegates_to_predicate_test() {
  let src = emit(has_spec())
  assert string.contains(
    src,
    "dsl.Predicate(leaf) -> tag_predicate_to_sql(leaf",
  )
}

// =============================================================================
// predicate_to_sql function
// =============================================================================

pub fn predicate_to_sql_fn_name_test() {
  let src = emit(has_spec())
  assert string.contains(src, "fn tag_predicate_to_sql(")
}

pub fn predicate_to_sql_has_arm_pattern_test() {
  let src = emit(has_spec())
  // Arm pattern should reference the constructor via the schema alias
  assert string.contains(src, "schema.Has(tag_id: tag_id)")
}

pub fn predicate_to_sql_exists_skeleton_test() {
  let src = emit(has_spec())
  // EXISTS subquery skeleton
  assert string.contains(src, "exists (select 1")
  assert string.contains(src, "trackbucket_tag")
  assert string.contains(src, "tag_id")
  assert string.contains(src, "trackbucket_id")
}

pub fn predicate_to_sql_target_table_join_test() {
  let src = emit(has_spec())
  // Junction joins to target table "tag"
  assert string.contains(src, "from \\\"trackbucket_tag\\\"")
  assert string.contains(src, "join \\\"tag\\\"")
}

pub fn predicate_to_sql_root_fk_condition_test() {
  let src = emit(has_spec())
  // WHERE clause references root FK col
  assert string.contains(src, "\\\"trackbucket_id\\\"")
}

pub fn predicate_to_sql_magic_id_condition_test() {
  let src = emit(has_spec())
  // Has body: t."id" = ?
  assert string.contains(src, "t.\\\"id\\\"")
  assert string.contains(src, "sqlight.int(tag_id)")
}

pub fn predicate_to_sql_two_arms_test() {
  let src = emit(two_arm_spec())
  assert string.contains(src, "schema.Has(tag_id: tag_id)")
  assert string.contains(src, "schema.IsAtLeast(tag_id: tag_id, value: value)")
}

pub fn predicate_to_sql_edge_attrib_condition_test() {
  let src = emit(two_arm_spec())
  // IsAtLeast body second condition: rel."value" >= ?
  assert string.contains(src, "rel.\\\"value\\\"")
}

// =============================================================================
// sql_with function
// =============================================================================

pub fn sql_with_fn_name_test() {
  let src = emit(has_spec())
  assert string.contains(src, "fn query_tracks_by_filter_sql_with(")
}

pub fn sql_with_select_structure_test() {
  let src = emit(has_spec())
  // SELECT from root table with alias
  assert string.contains(src, "select ")
  assert string.contains(src, "from \\\"trackbucket\\\" as tb")
}

pub fn sql_with_deleted_at_filter_test() {
  let src = emit(has_spec())
  assert string.contains(src, "\\\"deleted_at\\\" is null")
}

pub fn sql_with_order_by_test() {
  let src = emit(has_spec())
  assert string.contains(src, "order by ")
  assert string.contains(src, "updated_at")
}

// =============================================================================
// Public query function
// =============================================================================

pub fn public_query_fn_name_test() {
  let src = emit(has_spec())
  assert string.contains(src, "pub fn query_tracks_by_filter(")
}

pub fn public_query_fn_params_test() {
  let src = emit(has_spec())
  assert string.contains(src, "conn: sqlight.Connection")
  assert string.contains(src, "filter: schema.FilterExpressionScalar")
}

pub fn public_query_fn_calls_sql_with_test() {
  let src = emit(has_spec())
  assert string.contains(src, "query_tracks_by_filter_sql_with(filter)")
}

pub fn public_query_fn_calls_sqlight_query_test() {
  let src = emit(has_spec())
  assert string.contains(src, "sqlight.query(sql")
  assert string.contains(src, "row.trackbucket_row_decoder()")
}

// =============================================================================
// Bool filter decoder
// =============================================================================

pub fn bool_filter_decoder_fn_name_test() {
  let src =
    csql.emit_bool_filter_decoder(
      "filter_expression_decoder",
      "tag_expression_decoder",
      "schema.FilterExpressionScalar",
    )
  assert string.contains(src, "pub fn filter_expression_decoder()")
}

pub fn bool_filter_decoder_handles_all_tags_test() {
  let src =
    csql.emit_bool_filter_decoder(
      "filter_expression_decoder",
      "tag_expression_decoder",
      "schema.FilterExpressionScalar",
    )
  assert string.contains(src, "\"And\"")
  assert string.contains(src, "\"Or\"")
  assert string.contains(src, "\"Not\"")
  assert string.contains(src, "\"Predicate\"")
}

// =============================================================================
// Leaf scalar decoder
// =============================================================================

pub fn leaf_scalar_decoder_fn_name_test() {
  let src =
    csql.emit_leaf_scalar_decoder(
      "tag_expression_decoder",
      "schema.TagExpressionScalar",
      "schema",
      has_spec(),
    )
  assert string.contains(src, "pub fn tag_expression_decoder()")
}

pub fn leaf_scalar_decoder_has_arm_test() {
  let src =
    csql.emit_leaf_scalar_decoder(
      "tag_expression_decoder",
      "schema.TagExpressionScalar",
      "schema",
      has_spec(),
    )
  assert string.contains(src, "\"Has\"")
  assert string.contains(src, "schema.Has(tag_id: tag_id)")
}

pub fn leaf_scalar_decoder_int_field_uses_decode_int_test() {
  let src =
    csql.emit_leaf_scalar_decoder(
      "tag_expression_decoder",
      "schema.TagExpressionScalar",
      "schema",
      has_spec(),
    )
  assert string.contains(src, "decode.int")
}

pub fn leaf_scalar_decoder_two_arm_spec_test() {
  let src =
    csql.emit_leaf_scalar_decoder(
      "tag_expression_decoder",
      "schema.TagExpressionScalar",
      "schema",
      two_arm_spec(),
    )
  assert string.contains(src, "\"Has\"")
  assert string.contains(src, "\"IsAtLeast\"")
  // IsAtLeast has two fields
  assert string.contains(src, "schema.IsAtLeast(tag_id: tag_id, value: value)")
}

// =============================================================================
// Naming conventions
// =============================================================================

pub fn junction_table_lowercase_test() {
  // Root=TrackBucket, Target=Tag → junction = trackbucket_tag
  let src = emit(has_spec())
  assert string.contains(src, "trackbucket_tag")
}

pub fn root_fk_col_name_test() {
  // trackbucket_id
  let src = emit(has_spec())
  assert string.contains(src, "trackbucket_id")
}

pub fn target_fk_col_name_test() {
  // tag_id (the FK column in the junction pointing at the target)
  let src = emit(has_spec())
  assert string.contains(src, "tag_id")
}

// =============================================================================
// SubAnd flattening in WHERE suffix
// =============================================================================

pub fn and_body_produces_two_and_conditions_test() {
  let src = emit(two_arm_spec())
  // IsAtLeast arm should have two ` and ` prefixed conditions in its WHERE suffix
  // One for magic.id = ? and one for rel."value" >= ?
  // Count occurrences of " and " inside the IsAtLeast arm section.
  // We just check both conditions appear in the output.
  assert string.contains(src, "t.\\\"id\\\"")
  assert string.contains(src, "rel.\\\"value\\\"")
}

// =============================================================================
// OR and NOT in body
// =============================================================================

pub fn or_in_body_test() {
  let or_arm =
    ir.PredicateArm(
      constructor_name: "Either",
      bound_fields: [
        ir.BoundField(name: "a", type_: int_type()),
        ir.BoundField(name: "b", type_: int_type()),
      ],
      target_lambda_param: "_t",
      target_magic_param: "magic",
      edge_attribs_param: "_ea",
      edge_magic_param: "_em",
      body: ir.SubOr([
        ir.SubCompare(
          left: ir.TargetMagicAccess("id"),
          operator: ir.SubEq,
          right: ir.BoundParam("a"),
        ),
        ir.SubCompare(
          left: ir.TargetMagicAccess("id"),
          operator: ir.SubEq,
          right: ir.BoundParam("b"),
        ),
      ]),
    )
  let spec = ir.ComplexFilterPredicateSpec(..has_spec(), arms: [or_arm])
  let src = csql.emit_complex_filter_query(spec, default_ctx(), "query_x")
  // OR body should emit " and (...  or ...)"
  assert string.contains(src, " or ")
}

pub fn not_in_body_test() {
  let not_arm =
    ir.PredicateArm(
      constructor_name: "Excluded",
      bound_fields: [ir.BoundField(name: "tid", type_: int_type())],
      target_lambda_param: "_t",
      target_magic_param: "magic",
      edge_attribs_param: "_ea",
      edge_magic_param: "_em",
      body: ir.SubNot(ir.SubCompare(
        left: ir.TargetMagicAccess("id"),
        operator: ir.SubEq,
        right: ir.BoundParam("tid"),
      )),
    )
  let spec = ir.ComplexFilterPredicateSpec(..has_spec(), arms: [not_arm])
  let src = csql.emit_complex_filter_query(spec, default_ctx(), "query_x")
  assert string.contains(src, "not (")
}
