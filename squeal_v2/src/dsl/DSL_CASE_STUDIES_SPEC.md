# DSL tightening against `src/case_studies/*_schema.gleam`

## Scope

This pass trims `src/dsl/dsl.gleam` to what is **referenced from case-study schema modules**:

- `src/case_studies/fruit_schema.gleam`
- `src/case_studies/hippo_schema.gleam`
- `src/case_studies/library_manager_schema.gleam`
- `src/case_studies/library_manager_advanced_schema.gleam`

**Out of scope for the dependency scan (but still compile-time consumers of `dsl`):**

- `src/case_studies/*_db/**` (generated/runtime modules): they only use `dsl.MagicFields` in signatures and decoders, not the full DSL surface.
- `src/schema_definition/**`, `src/generators/skeleton.gleam`, `test/**`, `FILTER_SPEC.md`, `old/**`.

## What stayed (directly tied to those four schema files)

| Symbol | Used in |
|--------|---------|
| `age`, `exclude_if_missing`, `nullable` | `hippo_schema`, `fruit_schema`, `library_manager_advanced_schema` |
| `Mutual`, `BelongsTo`, `BacklinkWith` | `hippo_schema` (relationship shapes); `BelongsTo` also in library manager schemas |
| `MagicFields`, `Direction` / `Asc` / `Desc`, `order` (field + direction) | All four |
| `query`, `shape`, `order`, `filter_bool`, `filter_complex` | Query pipeline in all four (where applicable) |
| `BooleanFilter` | `FilterExpressionScalar` alias (`BooleanFilter(TagExpressionScalar)`); return type of `predicate_complex_tags_filter` |
| `any` | Body of `predicate_complex_tags_filter` |
| Phantom `Query(...)` types | Required so the pipeline type-checks |

## What was removed (not referenced in those schema files)

- **`MutualWith`** — no case-study schema uses it (only `Mutual`).
- **`Backlink`** — `hippo_schema` uses `BacklinkWith` only.
- **`SqlFilter`**, **`OneToManyJoinSqlNaming`** — not referenced in case-study schemas (older / planned SQL lowering; see questions below).
- **`has`**, **`not_has`**, **`has_with`**, **`WithPredicate`**, **`is_at_least` / `is_at_most` / `is_equal_to`** — not used in any of the four schema modules.
- **`BooleanFilter` variants** `OneToManyAssocHas`, `OneToManyAssocNotHas`, `OneToManyAssocCompare` — only constructed via the removed helpers; case-study predicates use `any` only.
- **`complex_filter`** and **`import gleam/list`** — the interpreter was only used inside `complex_filter`; no case-study schema calls it (they use `filter_complex` on the query pipeline plus a `predicate_*` helper).
- **`pred_satisfied`** — private dead code after the above.

## Design note: `any`

Previously `any` had a body that only `panic`’d without binding arguments, which can trigger unused-variable warnings. The implementation now binds `relationship` and `select` and discards them so the API stays the same but the intent is explicit: **not runnable Gleam**, only a form preserved for extractors / future codegen.

## Open questions

1. **Fold interpreter** — Config trees are `BooleanFilter(T)` with `Predicate` leaves; `predicate_*` maps each leaf to `BooleanFilter(assoc)`. There is no `complex_filter` fold in `dsl` yet—only `filter_complex` on the query pipeline. Should a `complex_filter(root, tree, predicate_fn)` interpreter live in `dsl` again, or stay out until the query AST extractor emits it?

2. **`SqlFilter` / `OneToManyJoinSqlNaming`** — Dropped as unused by case-study schemas. Is SQLite fragment generation still planned in this package, or only in `old/` / another repo? If it returns, should those types live next to the SQL backend instead of the schema DSL?

3. **`MutualWith` vs `Mutual`** — Schemas only use `Mutual`. Will optional edge attributes require `MutualWith` at the schema layer, or is `BelongsToWith` enough?

4. **Plain `Backlink`** — Removed because only `BacklinkWith` appears in `hippo_schema`. Do we need a backlink variant **without** relationship attributes for a future schema?

5. **Tests and string fixtures** — Some `test/dsl/*.gleam` snippets mention `dsl.filter` / `dsl.order(option.None)` style APIs that may predate `filter_bool` / phantom `Query`. Should those tests be refreshed in a follow-up so they match the tightened module?

6. **Case-study DB modules** — They import `dsl` only for `MagicFields`. If `dsl` is split into `dsl/schema_forms.gleam` vs `dsl/magic.gleam`, would you want generated code to depend on a smaller module?

## Verification

After edits, run from `squeal_v2`:

```bash
gleam build
gleam test
```

If anything outside the four schema files depended on a removed symbol, the compiler will report it; restore or relocate that API as you answer the questions above.
