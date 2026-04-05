# Option.None → SQL NULL and unique indexes

## Goal

Define and enforce correct behavior when `upsert` / `update` receive `option.None` for optional fields, so that **unique constraints and `ON CONFLICT` targets remain predictable** and we do not silently create rows or conflict paths that violate product expectations.

## Problem

Today, some paths bind `sqlight.null()` (or otherwise persist SQL `NULL`) when Gleam passes `option.None`. That interacts badly with uniqueness:

- **SQLite**: For a `UNIQUE` constraint, `NULL` is not equal to `NULL`; multiple rows may carry `NULL` in the same unique column(s). Upserts keyed on those columns may **not** hit the intended `ON CONFLICT` branch when `NULL` is involved.
- **Semantics**: If a column is “optional” in the model but participates in a unique key (alone or in a composite), clearing it to `NULL` can mean “many rows look distinct to the engine” while the application expected a single logical row or a single conflict target.
- **Inconsistency**: Non-optional `Option(T)` fields in generated code often use **sentinel** encodings via `api_help.opt_*_for_db` (e.g. empty string, `0`) specifically to avoid `NULL` in the wire representation. Option-scalar paths that bind `NULL` diverge from that story unless we document and test the distinction.

This spec is the contract: **what we store for `None`, when we use `NULL` vs sentinels, and how generated SQL must behave** so unique indexes and upserts stay coherent.

## Scope

- Generated `upsert_*` / `update_*` (and any shared helpers such as `api_update_delete`, `api_sql`, `api_help`).
- Schemas where optional fields appear in or alongside **unique** / **identity** columns (including composite identities and partial unique indexes if present in case studies).

Out of scope unless later amended: changing database vendors; chunking large batches (see `UPSERT_API_REVAMP_SPEC.md`).

## Requirements

1. **Document per-field strategy**  
   For each optional field kind (option-scalar vs non-option with sentinel, timestamps, text, etc.), the spec implementation must state explicitly:
   - whether `None` is stored as SQL `NULL`, a sentinel, or **omitted** from an update (see below).

2. **Unique / conflict safety**  
   For any column set used in `ON CONFLICT(...)` or declared unique in migrations:
   - `None` must not produce a stored representation that **defeats** conflict detection unless that is an explicit, documented choice (e.g. “soft delete” column excluded from conflict target).
   - If the only fix is application-level (e.g. never put nullable columns in the conflict target), generated APIs must **fail at codegen** or **document** the restriction with a diagnostic.

3. **Update semantics**  
   Clarify intended meaning of `None` on update:
   - **A)** “Leave column unchanged” → do not include in `SET` (or use `SET col = col`), **never** write `NULL` unless we explicitly support “clear to null”.
   - **B)** “Clear to null” → write `NULL` and accept unique/index implications; must be opt-in or only for columns that are not in unique targets.

   The implementation must pick one default and encode it consistently in generators and docs.

4. **Tests (mandatory before closing this work)**
   - **Unit / codegen**: assertions on generated SQL fragments or helper usage for representative entities (optional field in identity vs not; optional non-identity field).
   - **E2E / integration**: minimal schema with a **unique** constraint that previously failed or behaved surprisingly with `None`; reproduce the bug, then assert the fixed behavior (e.g. single row after two upserts, or stable conflict resolution).
   - **Regression**: case that demonstrates SQLite’s multi-`NULL` uniqueness behavior **either** is avoided by design **or** is explicitly tested as accepted behavior.

## Decisions (to fill in during review)

- Default for `update` when a field is `None`: leave unchanged vs set `NULL`?
- For `upsert` insert branch, is `None` always `NULL`, always sentinel, or field-type-dependent?
- Do we codegen-time forbid optional columns on unique keys, or fix encoding so conflicts work?

## Success criteria

- Failing tests describe the unique-index / upsert bug in minimal form.
- After the fix, those tests pass; no undocumented `NULL` vs sentinel split for conflict-relevant columns.

## Implementation checklist (todos)

### Phase 0 — Decisions

- [ ] Choose default **update** semantics for `None` (leave unchanged vs set `NULL`).
      -> two methods, one that leaves none unchanged or clears none
- [ ] Choose **upsert insert** encoding per field kind (`NULL` vs sentinel vs omit).
  - See previous
- [ ] Decide: codegen **reject** optional columns on unique keys vs fix encoding for conflicts.

### Phase 1 — Tests first

- [ ] Add **failing** E2E (or integration) repro: unique / `ON CONFLICT` + `option.None` where behavior is wrong today.
- [ ] Add **codegen or snapshot** test for generated SQL / bind shape on representative entities (optional in identity vs not).

### Phase 2 — Implementation

- [ ] Update generators: `api_update_delete`, `api_sql`, and related paths per chosen rules.
- [ ] Align `api_help` (`opt_*_for_db`, null binds) with documented per-field strategy.
- [ ] If needed: diagnostics when schema violates “safe unique” rules.

### Phase 3 — Close the loop

- [ ] Document per-field strategy in code comments or internal doc next to generators.
- [ ] **Regression** test for SQLite multi-`NULL` uniqueness (avoided or explicitly accepted).
- [ ] All new tests green; review **`OPERATIONS_PURE_DATA_SPEC.md`** so command payloads use the same encoding rules.
