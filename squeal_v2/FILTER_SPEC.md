We are describing a complex filter shape that has three parts:

1. **Tree / branching** — `dsl.BooleanFilter` in `dsl.gleam`: `And`, `Or`, `Not`, `Predicate`. Same shape for the wire and for the compiled side.
2. **`predicate_*` functions** — how the schema says each leaf parameter behaves when turned into SQL (see below).
3. **Boolean sublanguage** — allowed expressions inside the sites that codegen inspects (e.g. the callback body passed to `dsl.any`). See [BOOLEAN_SUBLANGUAGE_SPEC.md](BOOLEAN_SUBLANGUAGE_SPEC.md).

**Naming.** Application-domain leaf types use the suffix **`ParamExpressionScalar`**: a **closed** set of constructors chosen for that filter (not a generic “any JSON value”). The word _param_ matches the constrained prefix / payload you accept from the client. Implementations may still use older names until refactored.

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

**Intended meaning:** the **related item** the edge points to is identified by that id — **`magic_fields` refer to the linked row**, not the edge row.

We likely need **both** in the long run: **edge** magic fields (junction / edge table) and **target** magic fields (the related entity). The example below only uses target-side `magic_fields` for `Has`; edge attrs appear where comparisons use `edge_attribs`.

### Where is the boolean sublanguage allowed?

In the **leaves** of how the schema describes behavior: e.g. the **return** of each `dsl.any(..., fn(...) { ... })` branch — a **single expression tree** of allowed combinators, comparisons, field access, and whitelisted `dsl.*` calls. The outer **`case` on `TagParamExpressionScalar`** in `predicate_*` is normal Gleam and is **not** part of that sublanguage; only the **bodies** handed to the DSL are.

**Compiled pipeline (intent):** the schema-side function is in essence **copied/expanded** so that **leaves hold compiled SQL** (derived from those boolean fragments), and **And / Or / Not** are composed recursively on top — parallel to how `BooleanFilter` nests on the wire.

### `filter_complex` input shape

`filter_complex` accepts **only** a `BooleanFilter` (structured filter). The leaf type does **not** have to be a primitive “scalar” in the SQL sense — it must be whatever **closed param type** that filter is defined over (still encodable to JSON with the matching codec).

---

## Not decided yet (author does not know enough SQL yet)

Concrete choices still open:

- How **`dsl.any`** should lower to SQL (e.g. `EXISTS` subquery vs joins vs lateral — and how correlation works).
- Exact SQL semantics for helpers like **`dsl.exclude_if_missing`** (e.g. relationship to `NULL` on edge columns).

These should be filled in once the SQL lowering strategy is chosen.

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
