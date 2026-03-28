# Filter / `filter_complex` implementation roadmap

Structured checklist to execute the plan in order. After each phase, prefer a **short commit** so bisect stays usable.

**Specs (conceptual):** [FILTER_SPEC.md](FILTER_SPEC.md), [BOOLEAN_SUBLANGUAGE_SPEC.md](BOOLEAN_SUBLANGUAGE_SPEC.md).

---

## Phase 0 — Specs (edge magic fields & contracts)

**Goal:** Lock naming and callback shape before code churn.

| # | Task | Location |
|---|------|----------|
| 0.1 | Document **target vs edge** `MagicFields`, `EdgeAttribs`, and **four-parameter** `dsl.any` callback. | [FILTER_SPEC.md](FILTER_SPEC.md) (*Edge vs target* table + `dsl.any` note) |
| 0.2 | Allow boolean sublanguage to reference **edge** and **target** magic fields; note arity transition. | [BOOLEAN_SUBLANGUAGE_SPEC.md](BOOLEAN_SUBLANGUAGE_SPEC.md) |
| 0.3 | Keep **QUERY_SPEC.md** / **DSL_CASE_STUDIES_SPEC.md** aligned when `dsl.any` arity or parse rules change. | `QUERY_SPEC.md`, `src/dsl/DSL_CASE_STUDIES_SPEC.md` |

---

## Phase 1 — DSL and schema types

**Goal:** Types tell the truth; case studies compile with the new `any` shape.

| # | Task | Location |
|---|------|----------|
| 1.1 | Extend **`dsl.any`**: `fn(related, target_magic_fields, edge_attribs, edge_magic_fields) -> Bool` (names in docs; Gleam may use `_` prefixes). Update panic stub + module docs. | `src/dsl/dsl.gleam` |
| 1.2 | Update **`predicate_*`** bodies that call `dsl.any` to the new arity. | `src/case_studies/library_manager_advanced_schema.gleam` |
| 1.3 | Align **non-advanced** schema if it uses the same relationship pattern. | `src/case_studies/library_manager_schema.gleam` (if any `dsl.any` or mirrored types) |
| 1.4 | Grep **`dsl.any(`** across the repo and update every call site to the new arity. | `src/`, `test/` |
| 1.5 | If junction tables need **magic columns** in DB for `edge_magic_fields`, extend migration + **row** shapes. | `src/case_studies/library_manager_db/migration.gleam`, `row.gleam` (and generator inputs if applicable) |

---

## Phase 2 — Second (and third) example schema

**Goal:** Prove the design is not tag-specific; different `*ParamExpressionScalar` + `predicate_*` + relationships.

| # | Task | Location |
|---|------|----------|
| 2.1 | Add a **second** published schema with `filter_complex` + `List(BelongsTo(...))` + `predicate_*`, distinct leaf type from tags (e.g. stock band, date window, or a second entity graph). Options: extend **`fruit_schema`** / **`hippo_schema`** with a list edge, or add a small dedicated module under `src/case_studies/`. | `src/case_studies/*.gleam` |
| 2.2 | Optional **third** minimal schema if the generator still special-cases (e.g. `Mutual` vs `BelongsTo` only) — force abstraction. | same |
| 2.3 | Document the two+ examples in **DSL case studies** table. | `src/dsl/DSL_CASE_STUDIES_SPEC.md` |

---

## Phase 3 — Parser and schema-definition tests

**Goal:** `ComplexRecursive` + `predicate_*` + boolean sublanguage over **four** lambda params parse and snapshot cleanly.

| # | Task | Location |
|---|------|----------|
| 3.1 | If the AST for `dsl.any` callback changes (arity, parameter names), update **extractors** / visitors that locate the boolean subexpression. | `src/schema_definition/query.gleam`, related `schema_definition/*.gleam` |
| 3.2 | Extend **filter / predicate parse tests** for `exclude_if_missing`, combinators, and **edge vs target** field paths inside `any`. | `test/schema_definition/filter_bool_pred_parse_test.gleam` |
| 3.3 | **Function shape** tests: `query_*` + `filter_complex` + `predicate_*` naming and pipeline order. | `test/dsl/function_shape_tests.gleam` |
| 3.4 | **Entity / schema** rejection tests (`predicate_` prefix, public helpers). | `test/dsl/entity_object_schema_test.gleam` |
| 3.5 | Any **integration** tests that load full schema modules for squeal. | `test/schema_definition/` (glob), `test/dsl/` |

---

## Phase 4 — Code generation (must run on ≥2 schemas)

**Goal:** No hard-coded `library_manager` paths; generated `api` / `query` / codecs for **each** `filter_complex` query.

| # | Task | Location |
|---|------|----------|
| 4.1 | Teach **query spec → SQL** (or staged builder) for `Filter.ComplexRecursive`: walk `BooleanFilter`, apply named `predicate_*` expansion model, emit `EXISTS` / join strategy per [FILTER_SPEC.md](FILTER_SPEC.md) *Not decided yet* once chosen. | `src/generators/api/api.gleam`, `api_sql.gleam`, new helper module if needed |
| 4.2 | **`api_query.gleam`** (and friends): emit `query_*` fns for complex filter params — JSON decode, `sqlight.query`, bind order. Today only simple `Predicate(Compare)` is generatable; extend `query_is_generatable` / chunk builders. | `src/generators/api/api_query.gleam` |
| 4.3 | **JSON codecs** for `BooleanFilter(Leaf)` per leaf type (generated from schema types). | `src/generators/api/api_decoders.gleam`, `scalar_codecs.gleam`, `api_imports.gleam` |
| 4.4 | **Facade / api module** wiring: re-export pattern matches existing `library_manager_db/api.gleam`. | `src/generators/api/api_facade.gleam`, `api_chunks.gleam`, `api.gleam` |
| 4.5 | **Orchestration**: ensure `squeal_v2` (or main generator entry) runs new path for every schema module that defines a complex query. | `src/squeal_v2.gleam` |
| 4.6 | **Evolution / snapshot tests** for generated outputs **per** case study (at least library manager advanced + second schema from phase 2). | `test/evolution/api/*.gleam`, regenerate committed `*_db/` outputs as today for fruit/hippo |

**Abstraction check:** add a generator test or CI assertion that **two** different `QuerySpecDefinition` complex filters produce **distinct** SQL strings and param lists without branching on module name (use only `SchemaDefinition` / query model).

---

## Phase 5 — Hardening

| # | Task | Location |
|---|------|----------|
| 5.1 | Smoke: open DB, call generated API with a minimal JSON `filter_complex` payload, assert row count. | `test/` (optional; can fold into phase 6) |
| 5.2 | Error paths: malformed JSON, unknown leaf constructor, empty `And([])`. | decoder + runtime tests |
| 5.3 | Update **FILTER_SPEC** illustrative SQL if lowering choice in phase 4 differs from `EXISTS` sketch. | `FILTER_SPEC.md` |

---

## Phase 6 — Library manager E2E (filters on real data) — **last gate**

**Goal:** Prove the full stack for the primary case study: enough **tags**, **track buckets** (tracks), and **tag–bucket edges** (with weights / edge attrs where the schema uses them) that **complex JSON filters** return the expected rows — not just parse/codegen snapshots.

| # | Task | Location |
|---|------|----------|
| 6.1 | Extend or add tests next to the existing **`library_manager_e2e_test`** pattern (`:memory:` DB, `api.migrate`, generated upserts). | `test/evolution/e2e/library_manager.gleam` (or sibling `library_manager_filters_e2e.gleam`) |
| 6.2 | **Seed data:** multiple tags (e.g. several `upsert_tag_by_tag_label`), multiple track buckets (`upsert_trackbucket_by_bucket_title_and_artist`), and **edges** linking buckets to tags with **distinct** `value` / weights so `IsAtLeast`, `IsEqualTo`, `Has`, etc. differ. Requires whatever generated API exists for junction rows (or direct SQL in test only if API not generated yet — prefer API once available). | same |
| 6.3 | Call the generated **`query_tracks_by_view_config`** (or the actual emitted name from `library_manager_advanced_schema`) with **JSON** matching `BooleanFilter(TagExpressionScalar)` / `*ParamExpressionScalar`: single leaf, `And`, `Or`, `Not` combinations; assert listed bucket ids/titles match expectations. | same |
| 6.4 | Add at least one **negative** assertion: filter that should return **no** buckets, or exclude a bucket that would match a looser filter. | same |

This phase is blocked until **phase 4** emits the query fn + SQL + codecs for `query_tracks_by_view_config` (or equivalent).

---

## Quick file index (where things live today)

| Area | Files |
|------|--------|
| Filter AST | `src/dsl/dsl.gleam` (`BooleanFilter`, `any`, `filter_complex`) |
| Schema filter model | `src/schema_definition/schema_definition.gleam` (`Filter`, `ComplexRecursive`, `Pred`, `MissingBehavior`) |
| Query pipeline parse | `src/schema_definition/query.gleam` (`parse_filter_complex`, pipeline validation) |
| Simple filter SQL | `src/generators/api/api.gleam` (`expr_to_sql`, `custom_query_sql`) |
| Query fn emission | `src/generators/api/api_query.gleam` |
| Case studies | `src/case_studies/library_manager_advanced_schema.gleam`, `library_manager_schema.gleam`, `fruit_schema.gleam`, `hippo_schema.gleam` |
| Generated DB API pattern | `src/case_studies/library_manager_db/api.gleam`, `query.gleam` |
| Library manager E2E (current) | `test/evolution/e2e/library_manager.gleam` |

---

## Dependency order (summary)

```
Phase 0 (specs)
    → Phase 1 (DSL + types + migrations)
        → Phase 2 (second schema — can overlap late Phase 1)
            → Phase 3 (parser tests)
                → Phase 4 (generation — blocked until parse model stable)
                    → Phase 5 (hardening)
                        → Phase 6 (library manager filter E2E — final gate)
```

Parallelism: Phase 2.1 can start once `dsl.any` signature is decided (Phase 1.1); Phase 3 can stub tests that `skip` until parse supports four parameters.
