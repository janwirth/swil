# Predicate boolean sublanguage (DSL)

Boolean expressions that **SQL generation** must parse and lower live in a **restricted sublanguage**. They appear inside **DSL expansion sites** — for example the callback passed to `dsl.any` in `src/dsl/dsl.gleam` — not in arbitrary Gleam in a `predicate_*` function.

See [FILTER_SPEC.md](FILTER_SPEC.md) for how this fits **complex queries** (`filter_complex`, encodable `BooleanFilter(*ParamExpressionScalar)`, and `predicate_*` interpreters).

---

## Isolation

Parsing for codegen **treats these boolean expressions separately** from the rest of the predicate body. Typical site: `dsl.any(relationship, fn(item, target_magic_fields, edge_attribs, edge_magic_fields) { ... })` — only the body expression (when it is a single allowed tree) is the sublanguage target. (Until `dsl.any` gains the fourth parameter, three-parameter callbacks remain the parse target; see [FILTER_SPEC.md](FILTER_SPEC.md) *Edge vs target*.)

The parser **isolates** each allowed fragment (including nodes under `&&` / `||` / `!`) for lowering to SQL. Everything outside that fragment in `predicate_*` is normal Gleam and is **not** emitted as a portable filter expression.

---

## Allowed

- Boolean combinators on booleans (`&&`, `||`, `!` as Gleam expresses them).
- Comparisons (`==`, `!=`, `<`, `>`, `<=`, `>=`) between allowed operands.
- **Property access** on parameters in scope: root row, **target** `MagicFields` (related entity), **edge** `MagicFields` (junction row), edge attribute record, relationship item, and **values bound from the payload** / pattern matches (e.g. `tag_id`, `value`).
- Literals compatible with those comparisons.
- **Calls to the `dsl` module only** (e.g. `dsl.exclude_if_missing`, `dsl.nullable`, `dsl.age`). The exact whitelist is whatever the generator documents as expandible.

---

## Not allowed

- `let` bindings inside the subexpression.
- `case` / `if` / blocks used to compute the boolean — the boolean must be **one expression tree** of combinators, comparisons, field access, and `dsl.*` calls.
- Calls to **non-`dsl`** functions (schema helpers, stdlib, etc.).
- Extra user-defined lambdas beyond what the DSL API’s signature fixes.

---

## Example (inner expression only)

```gleam
magic_fields.id == tag_id
&& dsl.exclude_if_missing(edge_attribs.value) == value
```

Reference implementation context: `predicate_complex_tags_filter` in `src/case_studies/library_manager_advanced_schema.gleam`.
