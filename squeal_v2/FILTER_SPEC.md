# Filter & DSL spec (v2)

## Goals

- **`dsl.BooleanFilter(a)`** in `src/dsl/dsl.gleam` is the single recursive filter type: `And` / `Or` / `Not` / `Predicate(item: a)`.
- Schema modules own **payload types** for `Predicate` leaves (e.g. `TagExpressionScalar`); they do not duplicate another recursive filter ADT.
- **`schema_definition`** extracts filter metadata into `SchemaDefinition.filters` (unwrap filter param to `dsl.BooleanFilter(T)` → payload type `T`).

**Naming:** `query_*` for public query builders; `predicate_*` for the function passed to `dsl.filter_complex(spec, predicate_fn)`.

**Pipeline:** `dsl.query` → `dsl.shape` → optional `filter_bool` **or** `filter_complex` (mutually exclusive) → `dsl.order`. Phantom types in `dsl.Query` enforce ordering and single use of each step.

---

## 1. Two surfaces: config tree vs predicate interpreter

| Surface | Role | Gleam freedom |
|--------|------|----------------|
| **Filter argument** | Encodable config: `dsl.BooleanFilter(T)` (or alias). | Tree shape only; leaves are `Predicate` of `T`. |
| **`predicate_*` fn** | Maps each `T` variant to SQL-expandable `dsl.BooleanFilter(...)` (e.g. `BelongsTo` + `dsl.any`). | **May** use `case` / pattern match on `T`, `let`, and structure around `dsl.any`. |

Example: `predicate_complex_tags_filter` in `library_manager_advanced_schema.gleam` — outer `case tag_expression` is interpreter logic, not part of the serialized filter.

---

## 2. Leaf boolean expressions (strict sublanguage)

**Parsing for SQL generation must treat boolean expressions inside DSL expansion sites separately** from the rest of the predicate body. Typical site: the callback passed to `dsl.any`, e.g. comparing `magic_fields`, `edge_attribs`, and payload fields.

**Allowed in that subexpression only:**

- Boolean combinators on booleans (`&&`, `||`, `!` as Gleam expresses them).
- Comparisons (`==`, `!=`, `<`, `>`, `<=`, `>=`) between allowed operands.
- **Property access** on parameters in scope (root row, `MagicFields`, relationship item, edge attribute record, and **values bound from the payload** / pattern matches — e.g. `tag_id`, `value`).
- Literals compatible with those comparisons.
- **Calls to `dsl` module functions only** (e.g. `dsl.exclude_if_missing`, `dsl.nullable`, `dsl.age`) — the whitelist is whatever the generator documents as expandible.

**Not allowed there:**

- `let` bindings.
- `case` / `if` / blocks used to compute the boolean (the boolean must be one expression tree of combinators + comparisons + access + `dsl.*` calls).
- Calls to **non-`dsl`** functions (schema helpers, stdlib, etc.).
- Arbitrary nesting of control flow; no user lambdas except as fixed by the DSL API signature.

Reference shape (allowed inner expression only):

```gleam
magic_fields.id == tag_id
&& dsl.exclude_if_missing(edge_attribs.value) == value
```

The parser **isolates** this fragment (and siblings under `&&` / `||` / `!`) for lowering to SQL; everything outside it in `predicate_*` follows normal Gleam but is not emitted as a portable filter expression.

---

## `SchemaDefinition` and filter metadata

Extend the root model with `filters: List(FilterSpecDefinition)`. Resolve the filter parameter type to `dsl.BooleanFilter(T)` (through aliases); **`T` names the leaf payload** — no duplicate type string on the filter spec.

Logical `FilterTree` nodes mirror `BooleanFilter`: `FilterAnd` / `FilterOr` / `FilterNot` / `FilterPredicate(expr)` plus lowered `FilterLeaf` for codegen (`path`, operation, payload expressions) as needed. Parser responsibilities: build tree, validate `predicate_` prefix on the referenced function, reject unsupported forms with `UnsupportedSchema`.

**Encoding:** `BooleanFilter` is encodable when `T` is encodable. JSON-like: `And`/`Or` with child lists, `Not` with one child, `Predicate` with encoded `T`.

---

## Scope

**In:** shared `BooleanFilter`, encodable payloads, `schema_definition` filter extraction, naming aligned with `query_` / `predicate_`.

**Out (v2):** full SQL runtime for every leaf, cross-function inlining, legacy ad-hoc helper shapes.

---

## Acceptance

- Case study: `FilterExpressionScalar = dsl.BooleanFilter(TagExpressionScalar)` + `predicate_complex_tags_filter` + `query_tracks_by_view_config` using `filter_complex`.
- `SchemaDefinition` holds extracted `FilterSpecDefinition` entries.
- Recursive filter round-trips encoding without losing tree shape.
