# Recursive Filter Spec (v2)

## Goal

Make recursive filters a first-class, reusable capability:

- the recursive wrapper type is owned by `dsl`,
- schema modules only define terminal/filter-leaf types,
- and the schema parser stores recursive filter specs as structured metadata.

This keeps `filter_*` definitions generic and makes them available to generation/runtime code without case-study-specific parsing.

## Problem Statement

Today `library_manager_schema` defines:

- a local `RecursiveFilterSpec(terminal)` type,
- plus `filter_track_bucket_by_tag` that interprets recursive nodes and terminal tag expressions.

That works for one schema, but the recursive shape itself is not shared or encoded as a platform-level contract. We want the application to understand this pattern globally.

## Scope

In scope:

- shared recursive filter type in `src/dsl/dsl.gleam`,
- encodable recursive filter payloads,
- parser/model updates in `src/schema_definition/schema_definition.gleam`,
- extraction contract for `filter_*` functions.

Out of scope (v2):

- full SQL runtime implementation details for every leaf operation,
- cross-function inlining/optimization,
- backwards-compat for arbitrary ad-hoc helper shapes.

## DSL Contract

### 1) Move recursive wrapper to `dsl`

Add this shared type to `src/dsl/dsl.gleam`:

```gleam
pub type RecursiveFilterSpec(terminal) {
  RecursiveAnd(items: List(RecursiveFilterSpec(terminal)))
  RecursiveOr(items: List(RecursiveFilterSpec(terminal)))
  RecursiveNot(item: RecursiveFilterSpec(terminal))
  RecursiveTerminal(item: terminal)
}
```

Constructor names avoid clashing with `BooleanFilter`’s `And` / `Or` / `Not` in the same module.

Schema usage then becomes:

```gleam
pub type FilterConfigScalar = dsl.RecursiveFilterSpec(TagExpressionScalar)

pub fn filter_tag_complex(
  track_bucket: TrackBucket,
  filter: dsl.RecursiveFilterSpec(TagExpressionScalar),
) -> dsl.BooleanFilter(BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
  dsl.complex_filter(track_bucket, filter, terminal)
}
```

(`terminal` is a `pub fn terminal(track_bucket, <TerminalType>) -> dsl.BooleanFilter(...)` in the schema module, or an equivalent anonymous function.)

### 2) Encodable data type requirement

`dsl.RecursiveFilterSpec(terminal)` is considered encodable iff `terminal` is encodable.

Encoding shape (logical contract, not wire-format locked):

- `And` / `Or`: object with tag + `items`
- `Not`: object with tag + `item`
- `Terminal`: object with tag + terminal payload

Example JSON-like representation:

```text
{ "type": "And", "items": [ ... ] }
{ "type": "Not", "item": { ... } }
{ "type": "Terminal", "item": { "type": "Has", "tag_id": 3 } }
```

Implementation detail (derive/manual encoder) is decided by the scalar/codegen layer; this spec only fixes semantic shape.

## `filter_*` Authoring Contract

A public `filter_*` function is extractable if:

- name starts with `filter_`,
- return type is explicitly `dsl.BooleanFilter(...)`,
- parameter 1 is root entity/context,
- parameter 2 is `dsl.RecursiveFilterSpec(<TerminalType>)` OR an alias that resolves to that type,
- implementation is a single return expression: `dsl.complex_filter(root, filter, terminal_fn)` where `terminal_fn` has type `fn(root, <TerminalType>) -> dsl.BooleanFilter(a)`.

Inside `terminal_fn`, schema authors map the terminal variant to `dsl.BooleanFilter` leaves (for example via `dsl.any(...)` over a relationship).

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

**Why no separate `terminal_type_name` / `recursive_filter_type_name` on the model**

The second parameter’s type already carries everything:

- It must be (or alias to) `dsl.RecursiveFilterSpec(T)`.
- **`T` (the terminal)** is whatever you put in `Terminal(item: t)` in JSON and in code — e.g. `TagExpressionScalar` with variants `Has`, `IsAtLeast`, …

So the parser **resolves** `T` from parameter 2 (unwrap the type/alias to `RecursiveFilterSpec(T)`). Codegen and encoders use that `T` to know leaf variant names and fields. Duplicating `terminal_type_name` and `recursive_filter_type_name` strings on `FilterSpecDefinition` would rot out of sync with the real signature.

**Example (usage)**

```gleam
// Schema: terminal type is yours; wrapper is dsl’s.
pub type TagExpressionScalar { Has(tag_id: Int) /* ... */ }
pub type FilterConfigScalar = dsl.RecursiveFilterSpec(TagExpressionScalar)

pub fn filter_track_bucket_by_tag(
  track_bucket: TrackBucket,
  filter: FilterConfigScalar,
) -> dsl.BooleanFilter(BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
  dsl.complex_filter(track_bucket, filter, terminal)
}
```

Extracted metadata: `filter_track_bucket_by_tag`, parameter 1 = `TrackBucket`, parameter 2 type resolves to `dsl.RecursiveFilterSpec(TagExpressionScalar)` → terminal = `TagExpressionScalar`. No extra string fields required.

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
  FilterTerminal(terminal_expr: Expr)
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

- `FilterTerminal` preserves terminal expression identity before lowering.
- `FilterLeaf` is lowered/canonical form for generation/runtime.
- `path` remains relationship-path semantics, never raw SQL naming.

### 3) Parser responsibilities (where it hooks)

In the schema parsing pipeline:

- resolve aliases until parameter 2 is `dsl.RecursiveFilterSpec(T)`; **record `T`** from the type arguments (no separate `terminal_type_name` field on the definition),
- parse recursive shape (`And`/`Or`/`Not`) into `FilterTree`,
- parse `Terminal` branch and capture leaf operations as `FilterLeaf` (or keep `FilterTerminal` then lower later),
- store result in `SchemaDefinition.filters`.

Unsupported forms must emit `UnsupportedSchema` with function span and reason.

### 4) Query integration

No breaking change required for `QuerySpecDefinition` initially.

`query_*` functions keep accepting filter arguments as today; generator resolves whether the filter type maps to a known `FilterSpecDefinition` via type name and uses that metadata.

## Migration Plan

1. **Factor DSL into `src/dsl/dsl.gleam`**: add `RecursiveFilterSpec(terminal)`, `complex_filter(...)`, and any other shared filter scaffolding so schema modules only import `dsl` — no local copies of the recursive wrapper in case studies.
2. Switch schema aliases (e.g. `FilterConfigScalar = dsl.RecursiveFilterSpec(...)`) and delete duplicate `RecursiveFilterSpec` definitions from schema modules.
3. Extend `schema_definition.gleam` with `filters` + filter model nodes.
4. Implement parser extraction and populate `SchemaDefinition.filters` (unwrap param 2 to obtain terminal type `T`).
5. Add tests:
   - parser snapshot for extracted `filter_track_bucket_by_tag`,
   - encoding/decoding round-trip for recursive filter scalar payload,
   - e2e query using recursive filter input.

## Acceptance Criteria

- At least one case study (`library_manager`) uses `dsl.RecursiveFilterSpec(Terminal)`.
- `SchemaDefinition` contains extracted `FilterSpecDefinition` entries.
- Recursive filter payload can be encoded/decoded without losing tree structure.
- Removing local recursive type declarations does not reduce expressiveness.
