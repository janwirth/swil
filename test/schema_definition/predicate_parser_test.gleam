//// Unit tests for `schema_definition/predicate_parser`.
////
//// Exercises parsing of `predicate_*` functions from the
//// `library_manager_advanced_schema` case study.

import generators/api/complex_filter_ir as ir
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit
import schema_definition/parser as schema_parser
import schema_definition/predicate_parser
import schema_definition/schema_definition as sd
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

// =============================================================================
// Helpers
// =============================================================================

fn load_advanced_schema() {
  let assert Ok(src) =
    simplifile.read("src/case_studies/library_manager_advanced_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  def
}

fn find_predicate_fn(
  def: sd.SchemaDefinition,
  name: String,
) -> ir.ComplexFilterPredicateSpec {
  let assert Ok(f) =
    list.find(def.predicate_functions, fn(fun) { fun.name == name })
  let assert Ok(spec) = predicate_parser.parse(f)
  spec
}

// =============================================================================
// Top-level spec fields
// =============================================================================

pub fn spec_fn_name_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  assert spec.fn_name == "predicate_complex_tags_filter"
}

pub fn spec_root_param_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  assert spec.root_param_name == "track_bucket"
  assert spec.root_entity_type == "TrackBucket"
}

pub fn spec_leaf_param_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  assert spec.leaf_param_name == "tag_expression"
  assert spec.leaf_param_type == "TagExpressionScalar"
}

pub fn spec_return_types_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  assert spec.target_entity_type == "Tag"
  assert spec.edge_attribs_type == "TrackBucketRelationshipAttributes"
}

pub fn spec_relationship_field_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  assert spec.relationship_field == "tags"
}

pub fn spec_arm_count_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  assert list.length(spec.arms) == 4
}

// =============================================================================
// Has(tag_id) arm — single bound field, single compare
// =============================================================================

pub fn has_arm_constructor_name_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [has_arm, ..] = spec.arms
  assert has_arm.constructor_name == "Has"
}

pub fn has_arm_bound_fields_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [has_arm, ..] = spec.arms
  assert list.length(has_arm.bound_fields) == 1
  let assert [bf] = has_arm.bound_fields
  assert bf.name == "tag_id"
}

pub fn has_arm_body_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [has_arm, ..] = spec.arms
  // magic_fields.id == tag_id
  let assert ir.SubCompare(
    left: ir.TargetMagicAccess("id"),
    operator: ir.SubEq,
    right: ir.BoundParam("tag_id"),
  ) = has_arm.body
}

pub fn has_arm_lambda_params_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [has_arm, ..] = spec.arms
  // fn(_tag, magic_fields, _edge_attribs, _edge_magic)
  assert has_arm.target_magic_param == "magic_fields"
}

// =============================================================================
// IsAtLeast(tag_id, value) arm — AND of two conditions
// =============================================================================

pub fn is_at_least_arm_bound_fields_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [_, is_at_least_arm, ..] = spec.arms
  assert is_at_least_arm.constructor_name == "IsAtLeast"
  let field_names = list.map(is_at_least_arm.bound_fields, fn(bf) { bf.name })
  assert field_names == ["tag_id", "value"]
}

pub fn is_at_least_arm_body_and_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [_, is_at_least_arm, ..] = spec.arms
  // magic_fields.id == tag_id && exclude_if_missing(edge_attribs.value) >= value
  let assert ir.SubAnd(conditions) = is_at_least_arm.body
  assert list.length(conditions) == 2
}

pub fn is_at_least_arm_first_condition_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [_, is_at_least_arm, ..] = spec.arms
  let assert ir.SubAnd([first, _]) = is_at_least_arm.body
  let assert ir.SubCompare(
    left: ir.TargetMagicAccess("id"),
    operator: ir.SubEq,
    right: ir.BoundParam("tag_id"),
  ) = first
}

pub fn is_at_least_arm_second_condition_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [_, is_at_least_arm, ..] = spec.arms
  let assert ir.SubAnd([_, second]) = is_at_least_arm.body
  // dsl.exclude_if_missing(edge_attribs.value) >= value
  let assert ir.SubCompare(
    left: ir.EdgeAttribAccess("value", Some(ir.ExcludeIfMissing)),
    operator: ir.SubGe,
    right: ir.BoundParam("value"),
  ) = second
}

// =============================================================================
// IsAtMost arm — uses <=
// =============================================================================

pub fn is_at_most_arm_operator_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [_, _, is_at_most_arm, _] = spec.arms
  assert is_at_most_arm.constructor_name == "IsAtMost"
  let assert ir.SubAnd([_, second]) = is_at_most_arm.body
  let assert ir.SubCompare(
    left: ir.EdgeAttribAccess("value", Some(ir.ExcludeIfMissing)),
    operator: ir.SubLe,
    right: ir.BoundParam("value"),
  ) = second
}

// =============================================================================
// IsEqualTo arm — uses ==
// =============================================================================

pub fn is_equal_to_arm_operator_test() {
  let def = load_advanced_schema()
  let spec = find_predicate_fn(def, "predicate_complex_tags_filter")
  let assert [_, _, _, is_equal_to_arm] = spec.arms
  assert is_equal_to_arm.constructor_name == "IsEqualTo"
  let assert ir.SubAnd([_, second]) = is_equal_to_arm.body
  let assert ir.SubCompare(
    left: ir.EdgeAttribAccess("value", Some(ir.ExcludeIfMissing)),
    operator: ir.SubEq,
    right: ir.BoundParam("value"),
  ) = second
}

// =============================================================================
// Error cases (inline sources)
// =============================================================================

const minimal_schema_prefix = "import swil/dsl/dsl
import gleam/option

pub type Root {
  Root(identities: RootIdentities, relationships: RootRelationships)
}
pub type RootIdentities { ByRootKey(key: Int) }
pub type Target { Target(identities: TargetIdentities) }
pub type TargetIdentities { ByTargetKey(key: Int) }
pub type RootEdgeAttributes { RootEdgeAttributes }
pub type RootRelationships { RootRelationships(targets: List(dsl.BelongsTo(Target, RootEdgeAttributes))) }
pub type LeafScalar { LeafA(v: Int) }

"

pub fn error_wrong_relationship_field_per_arm_test() {
  // Two arms that reference different relationship fields should fail.
  let src =
    minimal_schema_prefix
    <> "pub fn predicate_multi_field(root: Root, leaf: LeafScalar) -> dsl.BooleanFilter(dsl.BelongsTo(Target, RootEdgeAttributes)) {
  case leaf {
    LeafA(v: v) ->
      dsl.any(
        root.relationships.targets,
        fn(_t, magic_fields, _ea, _em) { magic_fields.id == v },
      )
  }
}"
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(f) =
    list.find(def.predicate_functions, fn(f) {
      f.name == "predicate_multi_field"
    })
  let assert Ok(spec) = predicate_parser.parse(f)
  assert spec.relationship_field == "targets"
}

pub fn error_missing_return_annotation_test() {
  // A `predicate_*` function without an explicit `-> dsl.BooleanFilter(...)` return
  // annotation is rejected at the module-parse level (not just at predicate_parser.parse).
  let src =
    minimal_schema_prefix
    <> "pub fn predicate_no_return(root: Root, leaf: LeafScalar) {
  case leaf {
    LeafA(v: v) ->
      dsl.any(
        root.relationships.targets,
        fn(_t, magic_fields, _ea, _em) { magic_fields.id == v },
      )
  }
}"
  let assert Error(sd.UnsupportedSchema(_, msg)) =
    schema_parser.parse_module(src)
  // The error should mention the function name
  assert string.contains(msg, "predicate_no_return")
}
