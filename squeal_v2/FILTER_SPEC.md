# Recursive Filter Spec (v2)

## Goal

Make recursive filters a first-class, reusable capability:

- the recursive wrapper type is owned by `dsl`,
- schema modules only define **predicate payload** types (the custom type carried in each `RecursivePredicate` leaf),
- and the schema parser stores recursive filter specs as structured metadata.

Query specs use the `query_` prefix; BooleanFilter helpers use `predicate_` (enforced by `schema_definition` parsing).

## Naming (enforced convention)

Public functions passed as `predicate_fn` to `dsl.complex_filter` **must** use the prefix **`predicate_`**. Reference implementation: `predicate_complex_tags_filter` in `library_manager_schema_advanced.gleam`.

| Artefact | Rule | Canonical example |
|----------|------|-------------------|
| Recursive leaf constructor | `dsl.RecursiveFilterSpec` variant holding payload | `RecursivePredicate(item: TagExpressionScalar)` |
| Leaf interpreter `pub fn` | **`predicate_` prefix** | `predicate_complex_tags_filter` |
| `complex_filter` argument | labeled **`predicate_fn`** | `dsl.complex_filter(root, spec, predicate_fn: predicate_complex_tags_filter)` |

(Distinct from `dsl.WithPredicate`, which is only the numeric comparison wrapper for `has_with`.)

## Problem Statement

Earlier drafts used a local `RecursiveFilterSpec` plus hand-rolled recursion in the schema module. The target is a single shared recursive shape in `dsl` and consistent **predicate\_*** naming for leaf interpreters.

## Scope

In scope:

- shared recursive filter type in `src/dsl/dsl.gleam`,
- encodable recursive filter payloads,
- parser/model updates in `src/schema_definition/schema_definition.gleam`,
- extraction contract aligned with public function prefixes (`query_`, `predicate_`).

Out of scope (v2):

- full SQL runtime implementation details for every leaf operation,
- cross-function inlining/optimization,
- backwards-compat for arbitrary ad-hoc helper shapes.

## DSL Contract

### 1) Recursive wrapper in `dsl`

Add this shared type to `src/dsl/dsl.gleam`:

```gleam
pub type RecursiveFilterSpec(payload) {
  RecursiveAnd(items: List(RecursiveFilterSpec(payload)))
  RecursiveOr(items: List(RecursiveFilterSpec(payload)))
  RecursiveNot(item: RecursiveFilterSpec(payload))
  RecursivePredicate(item: payload)
}
```

Constructor names avoid clashing with `BooleanFilter`’s `And` / `Or` / `Not` in the same module. **`RecursivePredicate`** holds one instance of the schema-defined payload type (e.g. `TagExpressionScalar`).

Schema usage:

```gleam
pub type FilterConfigScalar = dsl.RecursiveFilterSpec(TagExpressionScalar)

pub fn filter_tag_complex(
  track_bucket: TrackBucket,
  filter: dsl.RecursiveFilterSpec(TagExpressionScalar),
) -> dsl.BooleanFilter(BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
  dsl.complex_filter(
    track_bucket,
    filter,
    predicate_fn: predicate_complex_tags_filter,
  )
}
```

### 2) Encodable data type requirement

`dsl.RecursiveFilterSpec(payload)` is encodable iff `payload` is encodable.

Encoding shape (logical contract, not wire-format locked):

- `RecursiveAnd` / `RecursiveOr`: tag + `items`
- `RecursiveNot`: tag + `item`
- `RecursivePredicate`: tag + payload

Example JSON-like representation:

```text
{ "type": "RecursiveAnd", "items": [ ... ] }
{ "type": "RecursiveNot", "item": { ... } }
{ "type": "RecursivePredicate", "item": { "type": "Has", "tag_id": 3 } }
```

Implementation detail (derive/manual encoder) is decided by the scalar/codegen layer; this spec only fixes semantic shape.

## Query + predicate authoring (public functions)

Public functions in a schema module are restricted to **`query_*`** and **`predicate_*`** (see `parse_error.hint_public_function_prefixes`).

A **`query_*`** spec uses the usual `(entity, dsl.MagicFields, simple)` parameters and ends in `dsl.query |> dsl.shape |> dsl.filter |> dsl.order`.

When the filter slot uses `dsl.complex_filter(...)`, pass a **`predicate_*`** function as `predicate_fn` (see naming table). That helper must be `pub fn predicate_…(root, payload) -> dsl.BooleanFilter(...)` (or equivalent) with an explicit BooleanFilter return annotation.

## Applying This To `schema_definition.gleam`

### 1) Extend root model

Add extracted filter specs to `SchemaDefinition`:

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
```

### 2) Add filter-specific definitions

**Why no duplicate type-name strings on `FilterSpecDefinition`**

The second parameter’s type already carries everything:

- It must be (or alias to) `dsl.RecursiveFilterSpec(T)`.
- **`T` (payload)** is whatever you put in `RecursivePredicate(item: t)` in JSON and in code — e.g. `TagExpressionScalar` with variants `Has`, `IsAtLeast`, …

So the parser **resolves** `T` from parameter 2 (unwrap the type/alias to `RecursiveFilterSpec(T)`). Codegen and encoders use that `T` to know leaf variant names and fields.

**Example (usage)**

```gleam
pub type TagExpressionScalar { Has(tag_id: Int) /* ... */ }
pub type FilterConfigScalar = dsl.RecursiveFilterSpec(TagExpressionScalar)

pub fn filter_track_bucket_by_tag(
  track_bucket: TrackBucket,
  filter: FilterConfigScalar,
) -> dsl.BooleanFilter(BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
  dsl.complex_filter(
    track_bucket,
    filter,
    predicate_fn: predicate_complex_tags_filter,
  )
}
```

Extracted metadata: `filter_track_bucket_by_tag`, parameter 1 = `TrackBucket`, parameter 2 resolves to `dsl.RecursiveFilterSpec(TagExpressionScalar)` → payload type = `TagExpressionScalar`. No extra string fields required.

Add these model types:

```gleam
pub type FilterSpecDefinition {
  FilterSpecDefinition(
    name: String,
    parameters: List(FilterParameter),
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
  FilterPredicate(predicate_expr: Expr)
  FilterLeaf(operation: FilterOperation, path: List(String), payload: FilterPayload)
}

pub type FilterOperation {
  Has
  NotHas
  HasWith
  Any
}

pub type FilterPayload {
  NoPayload
  RelatedId(value_expr: Expr)
  Comparison(operator: Operator, value_expr: Expr)
}
```

Design notes:

- `FilterPredicate` preserves payload expression identity before lowering.
- `FilterLeaf` is lowered/canonical form for generation/runtime.
- `path` remains relationship-path semantics, never raw SQL naming.

### 3) Parser responsibilities (where it hooks)

In the schema parsing pipeline:

- resolve aliases until parameter 2 is `dsl.RecursiveFilterSpec(T)`; **record `T`** from the type arguments,
- parse recursive shape into `FilterTree`,
- parse `RecursivePredicate` branch and capture leaf operations as `FilterLeaf` (or keep `FilterPredicate` then lower later),
- validate that the `predicate_fn` reference is a `pub fn` whose name starts with `predicate_`,
- store result in `SchemaDefinition.filters`.

Unsupported forms must emit `UnsupportedSchema` with function span and reason.

### 4) Query integration

No breaking change required for `QuerySpecDefinition` initially.

`query_*` functions keep accepting filter arguments as today; generator resolves whether the filter type maps to a known `FilterSpecDefinition` via type name and uses that metadata.

## Migration Plan

1. **Factor DSL into `src/dsl/dsl.gleam`**: `RecursiveFilterSpec`, `RecursivePredicate`, `complex_filter(...)`, etc.
2. Switch schema aliases (e.g. `FilterConfigScalar = dsl.RecursiveFilterSpec(...)`) and delete duplicate recursive types from schema modules.
3. Extend `schema_definition.gleam` with `filters` + filter model nodes.
4. Implement parser extraction and populate `SchemaDefinition.filters` (unwrap param 2 to obtain payload type `T`).
5. Add tests:
   - parser snapshot for extracted filters,
   - encoding/decoding round-trip for recursive filter payload,
   - e2e query using recursive filter input.

## Acceptance Criteria

- At least one case study uses `dsl.RecursiveFilterSpec` with a `predicate_*` interpreter (e.g. `predicate_complex_tags_filter`).
- `SchemaDefinition` contains extracted `FilterSpecDefinition` entries.
- Recursive filter payload can be encoded/decoded without losing tree structure.
- Removing local recursive type declarations does not reduce expressiveness.
