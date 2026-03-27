# Dynamic `filter_*` Helper Spec (v1)

## Goal

Enable schema authors to define public `filter_*` functions (like `filter_by_tag`) that:

- remain generic (no case-study hard-coding),
- preserve the full boolean expression tree in schema metadata,
- and compile to SQL at runtime with type-safe operator/value handling for the targeted relationship/entity.

This extends the existing query model in `src/schema_definition/query.gleam` and `src/schema_definition/schema_definition.gleam` without introducing consumer-written custom SQL.

## Motivation

`library_manager_schema.filter_by_tag` already shows the desired expressiveness:

- recursive `And` / `Or` / `Not`
- domain scalar leaves (`TagExpression`)
- relationship-aware leaves (`dsl.has`, `dsl.not_has`, `dsl.has_with`)

Today this shape is effectively hard-coded in the schema module. The target is to make this pattern first-class and generic in schema parsing + generation.

## Non-Negotiable Constraints

- No module-specific codegen logic.
- No fallback to manual SQL for schema-declared filters.
- Fail with explicit parser/codegen errors for unsupported helper shapes.
- Keep helper expression structure in AST/model (do not flatten to string SQL fragments).

## Proposed Contract

### 1) Public helper recognition

In `src/schema_definition/query.gleam`, treat public `filter_*` functions as extractable specs (not just permissive side helpers).

Required shape:

- function name starts with `filter_`
- explicit return annotation `-> dsl.BooleanFilter(...)`
- exactly 2 parameters:
  - first: target entity/root (for path resolution)
  - second: scalar/filter input type (for runtime value typing)

### 2) New schema model nodes

Extend `src/schema_definition/schema_definition.gleam`:

```gleam
pub type SchemaDefinition {
  SchemaDefinition(
    entities: List(EntityDefinition),
    identities: List(IdentityTypeDefinition),
    relationship_containers: List(RelationshipContainerDefinition),
    relationship_edge_attributes: List(RelationshipEdgeAttributesDefinition),
    scalars: List(ScalarTypeDefinition),
    queries: List(QuerySpecDefinition),
    filters: List(FilterSpecDefinition),
  )
}

pub type FilterSpecDefinition {
  FilterSpecDefinition(
    name: String,
    parameters: List(FilterParameter),
    input_type_name: String,
    target_type_name: String,
    tree: FilterTree,
  )
}

pub type FilterParameter {
  FilterParameter(label: Option(String), name: String, type_: glance.Type)
}

pub type FilterTree {
  FilterAnd(items: List(FilterTree))
  FilterOr(items: List(FilterTree))
  FilterNot(item: FilterTree)
  FilterLeaf(operation: FilterOperation, path: List(String), payload: FilterPayload)
}

pub type FilterOperation {
  Has
  NotHas
  HasWith
}

pub type FilterPayload {
  NoPayload
  ScalarValue(value_expr: Expr)
  Comparison(operator: Operator, value_expr: Expr)
}
```

Notes:

- `path` is relationship path from parameter 1 root, not SQL table/column names.
- leaf payload uses existing `Expr`/`Operator` primitives where possible.
- scalar AST literals can be added later if needed; initial scope can remain parameter/field/call-based.

### 3) Parser extraction rules (`query.gleam`)

Add extraction pipeline for `filter_*` helpers:

- Detect structural recursion over the second parameter type:
  - `And(exprs)` -> `FilterAnd(list.map(...))`
  - `Or(exprs)` -> `FilterOr(...)`
  - `Not(expr)` -> `FilterNot(...)`
- Detect supported DSL leaves:
  - `dsl.has(<relationship_path>, <value>)`
  - `dsl.not_has(<relationship_path>, <value>)`
  - `dsl.has_with(<relationship_path>, <value>, <predicate>)`
- Predicate mapping for `has_with`:
  - `dsl.is_at_least(v)` -> `Comparison(Ge, parse_expr(v))`
  - `dsl.is_at_most(v)` -> `Comparison(Le, parse_expr(v))`
  - `dsl.is_equal_to(v)` -> `Comparison(Eq, parse_expr(v))`

Unsupported forms are explicit parse errors with function name and span.

### 4) Runtime + codegen behavior

Generated API layer should expose helper execution through generic functions:

- parse scalar input (`FilterScalar`-like) into the preserved `FilterTree` form
- compile `FilterTree` to SQL via existing boolean filter SQL pipeline
- bind values according to inferred scalar type (`Int`, `Float`, `String`, custom `*Scalar` unwrap rules)

Compilation requirements:

- Preserve boolean grouping (`And`/`Or`/`Not`) exactly.
- Resolve relationship `path` using schema relationship metadata, not hard-coded table names.
- Use operator/type-specific SQL fragments generated from AST (`Eq`, `Ge`, `Le`, etc.).

### 5) Integration with query specs

`query_*` specs can stay unchanged and consume filter helpers as opaque inputs initially.

Optional next step:

- Allow `query_*` filter argument to reference extracted `FilterSpecDefinition` directly, so query specs can declare helper coupling explicitly.

## Validation Strategy

- Parser unit tests:
  - successful extraction of `library_manager_schema.filter_by_tag`
  - error cases for non-prefixed names, missing return annotation, unsupported leaf calls
- Model snapshots:
  - assert `SchemaDefinition.filters` includes expected AST
- SQL generation tests:
  - golden SQL for nested `And/Or/Not`
  - parameter binding order/type tests for `has_with` comparison values

## Incremental Rollout

1. Add `FilterSpecDefinition` model and schema container field.
2. Implement parser extraction + strict validation for `filter_*`.
3. Wire generic SQL compilation from `FilterTree`.
4. Migrate `library_manager` to use generated/runtime filter compilation path.
5. Add end-to-end test in `test/evolution/e2e/library_manager.gleam`.

## Open Questions

1. Should `filter_*` helpers be allowed to call other `filter_*` helpers, or only self-recursive in one function?
2. Do you want leaf support limited to `has` / `not_has` / `has_with` first, or should we include scalar field comparisons (`entity.field == x`) in v1?
3. For custom scalars in filter leaves, should we require explicit conversion hooks now, or defer until first concrete need?
4. Should `filter_*` remain a separate spec track (`SchemaDefinition.filters`) or be embedded as a variant under query/filter AST in one unified tree?
5. Do you want `query_*` extraction to validate helper compatibility at parse time (strict coupling), or at generation time (looser coupling)?
