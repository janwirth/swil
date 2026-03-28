We are describing a complex filter shape that has three parts:

1. **Tree / branching** — `dsl.BooleanFilter` in `dsl.gleam`: `And`, `Or`, `Not`, `Predicate`. Same shape for the wire and for the compiled side.
2. **`predicate_*` functions** — how the schema says each leaf parameter behaves when turned into SQL (see below).
3. **Boolean sublanguage** — allowed expressions inside the sites that codegen inspects (e.g. the callback body passed to `dsl.any`). See [BOOLEAN_SUBLANGUAGE_SPEC.md](BOOLEAN_SUBLANGUAGE_SPEC.md).

**Naming.** Application-domain leaf types use the suffix **`ParamExpressionScalar`**: a **closed** set of constructors chosen for that filter (not a generic “any JSON value”). The word _param_ matches the constrained prefix / payload you accept from the client. Implementations may still use older names until refactored.

**Implementation order:** phased checklist with file pointers — [FILTER_IMPLEMENTATION_TODO.md](FILTER_IMPLEMENTATION_TODO.md).

---

## Q&A (design decisions)

### What is the difference between `FilterParamExpressionScalar` and the return type of `predicate_*`?

They are the **same tree shape** (`BooleanFilter`) but **different type parameters** for **different stages**:

| Stage                             | Role                                                                                                                                | Typical type parameter                                                      |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| **On the wire / API**             | Client sends a structured filter; leaves are **domain param** variants only.                                                        | e.g. `BooleanFilter(TagParamExpressionScalar)`                              |
| **After `predicate_*` expansion** | Each leaf has been turned into what SQL generation needs (relationships, `dsl.any`, etc.). Leaves are no longer the raw param type. | e.g. `BooleanFilter(dsl.BelongsTo(Tag, TrackBucketRelationshipAttributes))` |

So: **encode/decode** the full `BooleanFilter(*ParamExpressionScalar)` from the client. **`filter_complex`** takes that tree plus a **`predicate_*`** of type `fn(root, leaf_param) -> BooleanFilter(internal_leaf)` (see `dsl.filter_complex`): for each **`Predicate(leaf_param)`** node, codegen applies **`predicate_*`** to that **one** leaf (the outer `case` on `TagParamExpressionScalar` lives here). **And / Or / Not** structure is preserved and composed **recursively**, parallel to the wire tree. **SQL gen** then walks the resulting internal `BooleanFilter`; boolean sublanguage fragments inside `dsl.any` (and similar) lower to SQL in those subtrees.

### JSON versioning and decode errors

No versioning for now. If decode fails, the **query fails with an error** (same as any other bad request payload).

### Leaf type (`*ParamExpressionScalar`)

**Closed set** of constructors; defined per application domain (example below: tag-related params).

### `Has(tag_id)` semantics (and magic fields)

**Intended meaning:** the **related item** the edge points to is identified by that id — comparisons on **`magic_fields`** (better name: **target magic fields**) refer to the **linked entity row** (`tag`, `human`, …), not the junction row.

### Edge vs target: three layers on a `BelongsTo` / `dsl.any` path

For `List(BelongsTo(Related, EdgeAttribs))` lowered through a junction table, distinguish:

| Slot | Gleam (planned `dsl.any` callback) | SQL source |
|------|--------------------------------------|------------|
| **Related value** | First parameter (`Tag`, …) — often `_` if only fields matter | Columns of the **target** table (optional; may duplicate magic-field access). |
| **Target magic fields** | `dsl.MagicFields` for the **related** row (`id`, `created_at`, … on `tag`) | Target table + standard magic columns. |
| **Edge attributes** | `EdgeAttribs` record (e.g. `TrackBucketRelationshipAttributes`) | **Domain** columns on the junction row (`value`, …), not the generic magic slot. |
| **Edge magic fields** | Second `dsl.MagicFields` for the **junction row** itself | Junction table’s `id`, `created_at`, `updated_at`, `deleted_at`, … |

**Callback arity (target):** `dsl.any` should accept a function **`fn(related, target_magic_fields, edge_attribs, edge_magic_fields) -> Bool`**. Today `src/dsl/dsl.gleam` still documents three parameters; adding **`edge_magic_fields`** is part of the implementation plan (see [FILTER_IMPLEMENTATION_TODO.md](FILTER_IMPLEMENTATION_TODO.md)).

**Boolean sublanguage** may read **all four** parameter groups (property access only — see [BOOLEAN_SUBLANGUAGE_SPEC.md](BOOLEAN_SUBLANGUAGE_SPEC.md)).

**`Has(tag_id)`** typically uses **target** `magic_fields.id` (or equivalent) so “has this tag” means the linked row’s id matches, not the junction row’s surrogate id.

### Where is the boolean sublanguage allowed?

In the **leaves** of how the schema describes behavior: e.g. the **return** of each `dsl.any(..., fn(...) { ... })` branch — a **single expression tree** of allowed combinators, comparisons, field access, and whitelisted `dsl.*` calls. The outer **`case` on `TagParamExpressionScalar`** in `predicate_*` is normal Gleam and is **not** part of that sublanguage; only the **bodies** handed to the DSL are.

**Compiled pipeline (intent):** the schema-side function is in essence **copied/expanded** so that **leaves hold compiled SQL** (derived from those boolean fragments), and **And / Or / Not** are composed recursively on top — parallel to how `BooleanFilter` nests on the wire.

### `filter_complex` input shape

`filter_complex` accepts **only** a `BooleanFilter` (structured filter). The leaf type does **not** have to be a primitive “scalar” in the SQL sense — it must be whatever **closed param type** that filter is defined over (still encodable to JSON with the matching codec).

**Valid** — the leaf type inside `Predicate(...)` is **not fixed**: it is whatever **closed type the schema defines for that query** (name it `TagParamExpressionScalar`, `PriceBandParam`, `RegionFilterParam`, …). The tree is always `dsl.BooleanFilter(that_type)`. The Gleam below is **one** domain (track–tag filters); another `filter_complex` query would use **its own** constructors and a matching `predicate_*` `case`.

```gleam
import dsl/dsl
// Example: leaf constructors `Has`, `IsEqualTo`, … from *this* schema’s
// `TagParamExpressionScalar` — not special to `dsl`, and not the only possible leaf type.

// Single leaf → type is `BooleanFilter(TagParamExpressionScalar)` for this query only
dsl.Predicate(Has(tag_id: 42))

// Nested tree — only `BooleanFilter` combinators + `Predicate(...)` leaves
dsl.And([
  dsl.Predicate(Has(tag_id: 1)),
  dsl.Or([
    dsl.Predicate(IsEqualTo(tag_id: 7, value: 100)),
    dsl.Not(dsl.Predicate(Has(tag_id: 99))),
  ]),
])
```

**Other domains (same shape, different leaf type)** — e.g. `BooleanFilter(StockParam)` with `dsl.Predicate(LowStock(threshold: 5))`, or `BooleanFilter(DateRangeParam)` with `dsl.Predicate(CreatedBetween(from: ..., to: ...))`. The codec and `predicate_*` for that query are generated or written against **that** type, not tags.

**Valid on the wire** — JSON (or other encoding) that decodes to `BooleanFilter(<leaf type for this query>)`, e.g. a tagged union per leaf constructor and a discriminated form for `And` / `Or` / `Not` / `Predicate` (exact JSON is defined by the generated codec for **that** param type).

**Not valid** — cannot be passed as the complex filter parameter:

- A **raw SQL string** or fragment (“client-chosen WHERE clause”) — nothing in this pipeline treats arbitrary SQL as input.
- An **unstructured** or **open-ended** value: arbitrary JSON object, `Dict`, dynamic map, or “any JSON” that is not exactly `BooleanFilter(<that query’s leaf type>)` — **decode fails → query error**.
- A **single primitive** where a tree is required: e.g. just `42` or `"rock"` with no `Predicate` / combinator wrapper (unless the schema explicitly defined the param type as a single scalar — then it would not be `filter_complex` over `BooleanFilter`, it would be a different query shape).
- **Leaves** that are not members of the **closed** param type for that query: e.g. `Predicate(UnknownOp(...))` or an extra constructor the server’s `predicate_*` does not handle — reject at decode time if the codec is closed, or fail when interpreting unknown tags if the wire format is extensible (this project currently assumes **closed** sets).

---

## `dsl.exclude_if_missing` → SQL (already defined in codegen)

This is **not** an open question: simple-query SQL generation already fixes the meaning.

1. **Parse model** — `exclude_if_missing(inner)` is recorded as `Compare(..., missing_behavior: ExcludeIfMissing)` on the structured filter (`MissingBehavior` in `schema_definition.gleam`; see also [QUERY_SPEC.md](QUERY_SPEC.md) on inference from `exclude_if_missing` vs `nullable`).

2. **SQL lowering** — In `generators/api/api.gleam`, `expr_to_sql` **unwraps** `ExcludeIfMissingFn` and emits SQL **only for the inner field** (same text as if the wrapper were not there):

```50:51:src/generators/api/api.gleam
    Call(func: ExcludeIfMissingFn, args: [inner]) ->
      expr_to_sql(inner, table_alias)
```

3. **Effect on rows** — The comparison appears in `WHERE` as usual (e.g. `... and <left_sql> <op> ?` from `custom_query_sql` in the same module). In SQL, if `<left_sql>` evaluates to **NULL**, the comparison is **UNKNOWN**, and **`WHERE` keeps only TRUE**, so those rows are **dropped**. No separate `IS NOT NULL` fragment is emitted today; three-valued logic gives the same result as “exclude missing” for these single-comparison predicates.

**Implication for `filter_complex` / `dsl.any`:** when those paths get a full SQL backend, **`exclude_if_missing(edge_attribs.value) op …`** should lower to the **underlying column** in the edge/junction SQL and use the **same NULL semantics** (unless you later choose to emit an explicit `IS NOT NULL` for clarity or optimization — behavior must stay equivalent).

---

## Not decided yet (author does not know enough SQL yet)

Concrete choices still open:

- How **`dsl.any`** should lower to SQL (e.g. `EXISTS` subquery vs joins vs lateral — and how correlation works).

Fill this in once the relationship / `any` lowering strategy is chosen.

---

## Example (schema excerpt)

```gleam
// Encodable filter: BooleanFilter + gleam_json, with a codec for the leaf param type.
// Decode failure → query error (no wire format versioning for now).
pub type FilterParamExpressionScalar =
  dsl.BooleanFilter(TagParamExpressionScalar)

// One leaf of the wire tree: filter_complex applies this at each Predicate(...) node.
pub fn predicate_complex_tags_filter(
  track_bucket: TrackBucket,
  tag_expression: TagParamExpressionScalar,
) -> dsl.BooleanFilter(dsl.BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
  case tag_expression {
    Has(tag_id: tag_id) ->
      dsl.any(
        track_bucket.relationships.tags,
        fn(_tag, tag_magic_fields, _edge_attribs, _edge_magic_fields) { tag_magic_fields.id == tag_id },
      )
    IsAtLeast(tag_id: tag_id, value: value) ->
      dsl.any(
        track_bucket.relationships.tags,
        fn(_tag, tag_magic_fields, edge_attribs, _edge_magic_fields) {
          tag_magic_fields.id == tag_id
          && dsl.exclude_if_missing(edge_attribs.value) >= value
        },
      )
    IsAtMost(tag_id: tag_id, value: value) ->
      dsl.any(
        track_bucket.relationships.tags,
        fn(_tag, tag_magic_fields, edge_attribs, _edge_magic_fields) {
          tag_magic_fields.id == tag_id
          && dsl.exclude_if_missing(edge_attribs.value) <= value
        },
      )
    IsEqualTo(tag_id: tag_id, value: value) ->
      dsl.any(
        track_bucket.relationships.tags,
        fn(_tag, tag_magic_fields, edge_attribs, _edge_magic_fields) {
          tag_magic_fields.id == tag_id
          && dsl.exclude_if_missing(edge_attribs.value) == value
        },
      )
  }
}

// Closed, domain-specific param leaf set for this filter.
pub type TagParamExpressionScalar {
  Has(tag_id: Int)
  IsAtLeast(tag_id: Int, value: Int)
  IsAtMost(tag_id: Int, value: Int)
  IsEqualTo(tag_id: Int, value: Int)
}
```

---

## Generated `api` module (illustrative)

Code generation for `filter_complex` is not wired end-to-end yet; the shape below matches how other queries are exposed from `case_studies/.../api.gleam` (thin wrapper over `query`) and how the schema parameter `complex_tag_filter_expression` is typed.

The client sends **JSON** for `FilterParamExpressionScalar`. The API decodes it before running SQL; **decode failure** returns an error (exact error type is up to the generator — e.g. map `json.DecodeError` into the same `Result` error as DB failures, or use a dedicated API error).

```gleam
// case_studies/library_manager_db/api.gleam (target shape)

import case_studies/library_manager_db/query
import case_studies/library_manager_advanced_schema as schema
import dsl/dsl
import gleam/json
import gleam/result
import sqlight

pub fn query_tracks_by_view_config(
  conn: sqlight.Connection,
  complex_tag_filter_json: String,
) -> Result(
  List(#(schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  use filter <- result.try(
    json.decode(complex_tag_filter_json, schema.filter_param_expression_scalar_decoder())
    |> result.map_error(fn(_) {
      sqlight.SqlightError(sqlight.GenericError, "invalid complex_tag_filter JSON", -1)
    }),
  )
  query.query_tracks_by_view_config(conn, filter)
}
```

### Matching `query` module (illustrative)

`query.query_tracks_by_view_config/2` does **not** exist in the tree yet; it would live next to the other generated fns in `case_studies/library_manager_db/query.gleam`. Shape: take the **already-decoded** `FilterParamExpressionScalar`, turn it into **`(sql_string, with_args)`** (that pairing is what codegen owns — it mirrors `predicate_*` + `BooleanFilter` structure), then run `sqlight.query` like every other list query.

```gleam
// case_studies/library_manager_db/query.gleam (illustrative)

import case_studies/library_manager_db/row
import case_studies/library_manager_advanced_schema as schema
import dsl/dsl
import sqlight

/// Codegen: expand the filter tree + tag predicate into SQL and bind values in `?` order.
fn tracks_by_view_config_sql_with(
  filter: schema.FilterParamExpressionScalar,
) -> #(String, List(sqlight.Value)) {
  todo as "generated from schema: filter_complex + predicate_complex_tags_filter"
}

pub fn query_tracks_by_view_config(
  conn: sqlight.Connection,
  filter: schema.FilterParamExpressionScalar,
) -> Result(List(#(schema.TrackBucket, dsl.MagicFields)), sqlight.Error) {
  let #(sql, with) = tracks_by_view_config_sql_with(filter)
  sqlight.query(
    sql,
    on: conn,
    with: with,
    expecting: row.trackbucket_with_magic_row_decoder(),
  )
}
```

The hand-written equivalent of **`tracks_by_view_config_sql_with`** for a **single** leaf `Predicate(Has(42))` would pair the SQL from **§1** (first example in the next section) with `with: [sqlight.int(42)]`. For `And` / `Or` / `Not`, codegen concatenates fragments and accumulates binds in a fixed traversal order (same order the `?` placeholders appear in the final string).

`sqlight.query` takes `with: List(sqlight.Value)` (e.g. from `sqlight.int`, `sqlight.text`, …).

---

## Example call → SQL (illustrative)

Assume:

- Root entity rows live in `trackbucket` (alias `tb`).
- The `tags` relationship is stored as a junction/edge table `trackbucket_tag` (alias `rel`) with `trackbucket_id`, `tag_id`, and optional `value` (matches `TrackBucketRelationshipAttributes`).
- Related tag rows are in `tag` (alias `t`).

**Lowering style used here:** each `dsl.any` becomes an **`EXISTS` subquery** correlated on the root row. This is one plausible option; see [Not decided yet](#not-decided-yet-author-does-not-know-enough-sql-yet).

### 1. Wire JSON → single leaf `Has` with `tag_id = 42`

After decode, the filter is `Predicate(Has(42))`. **Illustrative SQL** (one bind: `42`):

```sql
select
  "title", "artist", "id", "created_at", "updated_at", "deleted_at"
from "trackbucket" as tb
where tb."deleted_at" is null
  and exists (
    select 1
    from "trackbucket_tag" as rel
    join "tag" as t
      on t."id" = rel."tag_id" and t."deleted_at" is null
    where rel."trackbucket_id" = tb."id"
      and t."id" = ?
  )
order by tb."updated_at" desc;
```

### 2. Same schema, leaf `IsEqualTo(tag_id: 7, value: 100)`

Matches `tag_magic_fields.id == 7` and `exclude_if_missing(edge_attribs.value) == 100`. Codegen unwraps `exclude_if_missing` to the **edge `value` column** only; **NULL** on that column makes `= ?` unknown, so the `EXISTS` branch fails — same as excluding missing (see the **`dsl.exclude_if_missing` → SQL** section above). **Illustrative SQL** (binds `7`, `100`):

```sql
-- same select / from / order as above
where tb."deleted_at" is null
  and exists (
    select 1
    from "trackbucket_tag" as rel
    join "tag" as t
      on t."id" = rel."tag_id" and t."deleted_at" is null
    where rel."trackbucket_id" = tb."id"
      and t."id" = ?
      and rel."value" = ?
  )
```

### 3. Tree on the wire: `And(Predicate(Has(1)), Predicate(Has(2)))`

**Illustrative `WHERE` fragment:** two `EXISTS` combined with `and` (each with its own bind list in order).

```sql
where tb."deleted_at" is null
  and exists ( ... and t."id" = ? )  -- tag 1
  and exists ( ... and t."id" = ? )  -- tag 2
```

### 4. Tree: `Or(Predicate(Has(1)), Predicate(Has(2)))`

```sql
where tb."deleted_at" is null
  and (
    exists ( ... and t."id" = ? )
    or exists ( ... and t."id" = ? )
  )
```

`Not(...)` would wrap the corresponding SQL fragment in `not (...)`.

Table and column names here follow the library-manager case study; a real generator would emit identifiers from the schema and might choose joins instead of nested `EXISTS`.
