# Recursive filter and DSL spec (v2)

## Overview

### Goal

Make recursive filters a first-class, reusable capability:

- the recursive wrapper type is owned by `dsl`,
- schema modules only define **predicate payload** types (the custom type carried in each `Predicate` leaf of `BooleanFilter`),
- and the schema parser stores recursive filter specs as structured metadata.

Query specs use the `query_` prefix; BooleanFilter helpers use `predicate_` (enforced by `schema_definition` parsing).

### Problem statement

Earlier drafts used a separate `RecursiveFilterSpec` type; that shape is merged into `dsl.BooleanFilter` (`And` / `Or` / `Not` / `Predicate`). Schema modules use consistent **predicate\_\*** naming for leaf interpreters.

### Scope

**In scope:**

- shared recursive filter type in `src/dsl/dsl.gleam`,
- encodable recursive filter payloads,
- parser/model updates in `src/schema_definition/schema_definition.gleam`,
- extraction contract aligned with public function prefixes (`query_`, `predicate_`).

**Out of scope (v2):**

- full SQL runtime implementation details for every leaf operation,
- cross-function inlining/optimization,
- backwards-compat for arbitrary ad-hoc helper shapes.

---

## Query

### Phantom pipeline type

`dsl.Query` is `Query(root, shape, filter, order)` with **phantom** parameters that track the pipeline:

1. `query(root)` — no shape, filter, or order yet.
2. `shape(...)` — requires an unset shape slot; records the projection type.
3. Optional `filter_bool` **or** `filter_complex` — requires shape set, filter unset, order unset; the two filter APIs are mutually exclusive after one is used.
4. `order(...)` — requires shape set and order unset; filter slot may be still unset or already set.

Pipeline steps that return a value re-wrap with `Query(root: r)` so the phantom parameters advance while the runtime payload stays the same `root`. Duplicate `shape` / `filter_*` / `order` steps fail at compile time.

### Naming (enforced convention)

Public functions passed as the second argument to `dsl.filter_complex(..., predicate_fn)` **must** use the prefix **`predicate_`**. Reference implementation: `predicate_complex_tags_filter` in `library_manager_advanced_schema.gleam`.

| Artefact                  | Rule                                                                                     | Canonical example                                                                  |
| ------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Leaf constructor          | `dsl.BooleanFilter` carrying payload type `T`                                            | `Predicate(item: TagExpressionScalar)`                                             |
| Leaf interpreter `pub fn` | **`predicate_` prefix**                                                                  | `predicate_complex_tags_filter`                                                    |
| Pipeline filter           | **`filter_complex(spec, predicate_fn)`** (no separate `complex_filter` in current `dsl`) | `dsl.filter_complex(complex_tag_filter_expression, predicate_complex_tags_filter)` |

### Query and predicate authoring

Public functions in a schema module are restricted to **`query_*`** and **`predicate_*`** (see `parse_error.hint_public_function_prefixes`).

A **`query_*`** spec uses the usual `(entity, dsl.MagicFields, simple)` parameters and ends in:

`dsl.query |> dsl.shape |> [dsl.filter_bool \| dsl.filter_complex]? |> dsl.order(field, direction)`

When the filter slot uses `dsl.filter_complex(spec, predicate_fn)`, pass a **`predicate_*`** function as `predicate_fn` (see naming table). That helper must be `pub fn predicate_…(root, payload) -> dsl.BooleanFilter(...)` (or equivalent) with an explicit BooleanFilter return annotation.

---

## Entities and schema model

### `SchemaDefinition` root model

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

### Query integration

No breaking change required for `QuerySpecDefinition` initially.

`query_*` functions keep accepting filter arguments as today; generator resolves whether the filter type maps to a known `FilterSpecDefinition` via type name and uses that metadata.

---

## Relationships and recursive filters

### Recursive filter tree in `dsl`

Shared type in `src/dsl/dsl.gleam`:

```gleam
pub type BooleanFilter(a) {
  And(exprs: List(BooleanFilter(a)))
  Or(exprs: List(BooleanFilter(a)))
  Not(expr: BooleanFilter(a))
  Predicate(item: a)
}
```

**`Predicate`** holds one instance of the schema-defined payload type (e.g. `TagExpressionScalar`). The same type parameter `a` also tags trees produced by `predicate_*` helpers (e.g. `BooleanFilter(BelongsTo(...))`).

Schema usage (see `library_manager_advanced_schema.gleam`):

```gleam
pub type FilterExpressionScalar = dsl.BooleanFilter(TagExpressionScalar)

pub fn predicate_complex_tags_filter(
  track_bucket: TrackBucket,
  tag_expression: TagExpressionScalar,
) -> dsl.BooleanFilter(BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
  panic as "see library_manager_advanced_schema.gleam"
}

pub fn query_tracks_by_view_config(
  track_bucket: TrackBucket,
  magic_fields: dsl.MagicFields,
  complex_tag_filter_expression: FilterExpressionScalar,
) {
  dsl.query(track_bucket)
  |> dsl.shape(option.None)
  |> dsl.filter_complex(complex_tag_filter_expression, predicate_complex_tags_filter)
  |> dsl.order(dsl.MagicFields, dsl.Desc)
}
```

### Encodable data type requirement

`dsl.BooleanFilter(payload)` is encodable iff `payload` is encodable (for config trees built with `Predicate` leaves).

Encoding shape (logical contract, not wire-format locked):

- `And` / `Or`: tag + `items` (or `exprs`)
- `Not`: tag + `expr` (or `item`)
- `Predicate`: tag + payload

Example JSON-like representation:

```text
{ "type": "And", "items": [ ... ] }
{ "type": "Not", "expr": { ... } }
{ "type": "Predicate", "item": { "type": "Has", "tag_id": 3 } }
```

Implementation detail (derive/manual encoder) is decided by the scalar/codegen layer; this spec only fixes semantic shape.

### Filter-specific definitions (`FilterSpecDefinition`)

**Why no duplicate type-name strings on `FilterSpecDefinition`**

The filter parameter’s type (typically the third slot after entity and `dsl.MagicFields`) already carries everything:

- It must be (or alias to) `dsl.BooleanFilter(T)`.
- **`T` (payload)** is whatever you put in `Predicate(item: t)` in JSON and in code — e.g. `TagExpressionScalar` with variants `Has`, `IsAtLeast`, …

So the parser **resolves** `T` from that parameter (unwrap the type/alias to `BooleanFilter(T)`). Codegen and encoders use that `T` to know leaf variant names and fields.

Extracted metadata for `query_tracks_by_view_config`: parameter 1 = `TrackBucket`, parameter 3 resolves to `dsl.BooleanFilter(TagExpressionScalar)` (or an alias such as `FilterExpressionScalar`) → payload type = `TagExpressionScalar`. No extra string fields required.

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

---

## Parser (`schema_definition`)

### Responsibilities (where it hooks)

In the schema parsing pipeline:

- resolve aliases until the filter parameter type is `dsl.BooleanFilter(T)`; **record `T`** from the type arguments,
- parse recursive shape into `FilterTree`,
- parse `Predicate` branch and capture leaf operations as `FilterLeaf` (or keep `FilterPredicate` then lower later),
- validate that the `predicate_fn` reference is a `pub fn` whose name starts with `predicate_`,
- store result in `SchemaDefinition.filters`.

Unsupported forms must emit `UnsupportedSchema` with function span and reason.

---

## Migration plan

1. **Keep recursive filter tree in `src/dsl/dsl.gleam`** as `BooleanFilter` with `Predicate` leaves.
2. Schema aliases use `FilterConfigScalar = dsl.BooleanFilter(...)` (no duplicate recursive types in schema modules).
3. Extend `schema_definition.gleam` with `filters` + filter model nodes.
4. Implement parser extraction and populate `SchemaDefinition.filters` (unwrap param 2 to obtain payload type `T`).
5. Add tests:
   - parser snapshot for extracted filters,
   - encoding/decoding round-trip for recursive filter payload,
   - e2e query using recursive filter input.

---

## Acceptance criteria

- At least one case study uses `dsl.BooleanFilter(T)` for filter config with a `predicate_*` interpreter (e.g. `predicate_complex_tags_filter` in `library_manager_advanced_schema`).
- `SchemaDefinition` contains extracted `FilterSpecDefinition` entries.
- Recursive filter payload can be encoded/decoded without losing tree structure.
- Removing local recursive type declarations does not reduce expressiveness.
