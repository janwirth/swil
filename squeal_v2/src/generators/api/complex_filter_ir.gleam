//// Internal representation (IR) for a parsed `predicate_*` function.
////
//// Pipeline:
////   schema source → `predicate_parser` → `ComplexFilterPredicateSpec` → `complex_filter_sql` → Gleam code strings
////
//// Intentionally kept separate from both `schema_definition` (parse layer) and the emitted
//// Gleam strings (codegen layer).  This is the typed bridge between them.

import glance
import gleam/option.{type Option}

// =============================================================================
// Top-level predicate spec
// =============================================================================

/// Parsed IR for one `predicate_*` function.
///
/// Example source:
/// ```gleam
/// pub fn predicate_complex_tags_filter(
///   track_bucket: TrackBucket,
///   tag_expression: TagExpressionScalar,
/// ) -> dsl.BooleanFilter(dsl.BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
///   case tag_expression { ... }
/// }
/// ```
pub type ComplexFilterPredicateSpec {
  ComplexFilterPredicateSpec(
    /// Name as declared in the schema module, e.g. `"predicate_complex_tags_filter"`.
    fn_name: String,
    /// Name of the root entity parameter, e.g. `"track_bucket"`.
    root_param_name: String,
    /// Type of the root entity parameter, e.g. `"TrackBucket"`.
    root_entity_type: String,
    /// Name of the leaf/param parameter, e.g. `"tag_expression"`.
    leaf_param_name: String,
    /// Type name of the leaf parameter, e.g. `"TagExpressionScalar"`.
    leaf_param_type: String,
    /// Relationship field name on the entity's Relationships record, e.g. `"tags"`.
    /// Derived from the path `root_param.relationships.<field>` in the `dsl.any` call.
    relationship_field: String,
    /// Type name of the related (target) entity, e.g. `"Tag"`.
    /// Determines the target table: `string.lowercase(target_entity_type)`.
    target_entity_type: String,
    /// Type name of the edge attributes record, e.g. `"TrackBucketRelationshipAttributes"`.
    edge_attribs_type: String,
    /// One arm per leaf-type constructor variant, in declaration order.
    arms: List(PredicateArm),
  )
}

// =============================================================================
// Per-variant arm
// =============================================================================

/// IR for one `case` arm in the predicate function body.
///
/// Example source arm:
/// ```gleam
/// IsAtLeast(tag_id: tag_id, value: value) ->
///   dsl.any(
///     track_bucket.relationships.tags,
///     fn(_tag, magic_fields, edge_attribs, _edge_magic) {
///       magic_fields.id == tag_id
///       && dsl.exclude_if_missing(edge_attribs.value) >= value
///     },
///   )
/// ```
pub type PredicateArm {
  PredicateArm(
    /// Constructor name matched in the `case`, e.g. `"Has"`, `"IsAtLeast"`.
    constructor_name: String,
    /// Fields bound by the constructor pattern, in declaration order.
    bound_fields: List(BoundField),
    /// Name of the first lambda parameter (the target entity value; often `_tag`).
    target_lambda_param: String,
    /// Name of the second lambda parameter (target entity's `MagicFields`).
    target_magic_param: String,
    /// Name of the third lambda parameter (edge/junction attributes).
    edge_attribs_param: String,
    /// Name of the fourth lambda parameter (edge/junction row's `MagicFields`).
    edge_magic_param: String,
    /// Parsed boolean sublanguage body of the lambda.
    body: BoolSubExpr,
  )
}

/// A named field bound by a constructor pattern, with its Glance type annotation.
///
/// Example: `tag_id: Int` inside `IsAtLeast(tag_id: tag_id, value: value)`.
pub type BoundField {
  BoundField(name: String, type_: glance.Type)
}

// =============================================================================
// Boolean sublanguage expression tree
// =============================================================================

/// Recursive boolean expression tree inside a `dsl.any` lambda body.
///
/// Only the operators and combinators listed here are part of the supported
/// boolean sublanguage (see BOOLEAN_SUBLANGUAGE_SPEC.md).
pub type BoolSubExpr {
  /// `a && b` — logical AND of two or more conditions (flattened from nested `&&`).
  SubAnd(List(BoolSubExpr))
  /// `a || b` — logical OR of two or more conditions (flattened from nested `||`).
  SubOr(List(BoolSubExpr))
  /// `!a` — logical NOT.
  SubNot(BoolSubExpr)
  /// Binary comparison between two leaf values.
  SubCompare(left: SubLeaf, operator: SubOperator, right: SubLeaf)
}

// =============================================================================
// Leaf values
// =============================================================================

/// Terminal values that appear as operands in `SubCompare`.
pub type SubLeaf {
  /// Access to the target entity's standard `MagicFields` (id, created_at, …).
  /// Source: `<target_magic_param>.<field>`, e.g. `magic_fields.id`.
  TargetMagicAccess(field: String)

  /// Access to an edge attribute field on the junction row, optionally wrapped
  /// in `dsl.exclude_if_missing` or `dsl.nullable`.
  /// Source: `edge_attribs.<field>` or `dsl.exclude_if_missing(edge_attribs.<field>)`.
  EdgeAttribAccess(field: String, missing_behavior: Option(EdgeMissingBehavior))

  /// Access to the junction row's own `MagicFields`.
  /// Source: `<edge_magic_param>.<field>`, e.g. `edge_magic.id`.
  EdgeMagicAccess(field: String)

  /// A constructor-bound parameter name, e.g. `tag_id` or `value`.
  BoundParam(name: String)

  /// Integer literal.
  LiteralInt(Int)

  /// Float literal.
  LiteralFloat(Float)

  /// String literal.
  LiteralString(String)

  /// Boolean literal.
  LiteralBool(Bool)
}

/// How a nullable edge attribute column is handled when its value is missing.
pub type EdgeMissingBehavior {
  /// `dsl.exclude_if_missing(...)` — NULL makes the comparison UNKNOWN → row excluded.
  ExcludeIfMissing
  /// `dsl.nullable(...)` — NULL propagates; caller decides semantics.
  Nullable
}

/// Comparison operators recognized in the boolean sublanguage.
pub type SubOperator {
  SubEq
  SubNe
  SubLt
  SubGt
  SubLe
  SubGe
}
