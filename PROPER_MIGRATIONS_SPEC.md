# Proper migrations (forward evolution, not idempotent replay)

## Goal

Migrations must be **ordered, one-way steps** on a real database state: after each step, **reads and queries that the product relies on keep working** on data inserted before that step. Generated row types may gain or lose fields across versions (e.g. `ImportedTrack`: `added_to_library_at` only in v2+, `external_source_url` only where the adapter exists); the contract is **schema + API + query behavior** at every boundary, not “safe to run `migrate` twice.”

## Why idempotent migrations are a poor fit here

- **Idempotency** optimizes for “run the same migration again and get the same final DDL.” That hides whether **intermediate** schemas and **existing rows** are still queryable the way the app expects.
- **Versioned codegen** (v1 DB vs v2 DB) already fixes the **logical** model per version; re-applying or conflating steps with idempotent `IF NOT EXISTS` style logic does not substitute for **per-step correctness** when columns are added, dropped, or reordered with SQLite constraints (indexes before `DROP COLUMN`, etc.).
- The failure mode we care about is **“migrated once, but `query_track_by_source_root` / identity lookups / ordering break”** — not “second `migrate` no-ops.”

## Requirements

1. **Linear chain**  
   Document and test migrations as `v1 → v2 → …` only. Each step applies exactly the DDL (and index drops/adds) required for that transition.

2. **Data + query checkpoints**  
   For each case study that evolves (e.g. imported track):
   - Insert rows using the **API at version N** (realistic payloads, including `option.None` where columns do not exist yet).
   - Run **`migrate` to N+1** (or the next step).
   - Immediately assert **representative queries** still succeed and match expectations: get by composite identity, filters on `from_source_root`, ordering on nullable timestamps where applicable, etc.
   - Repeat until the latest version; optionally upsert again on the latest schema and assert round-trip.

3. **No reliance on “migrate is harmless if repeated”**  
   Tests and docs must not assume double-`migrate` is the definition of correct; correctness is **first-time forward migration with live data and queries at every step**.

4. **E2E is mandatory**  
   One test per evolution path that mirrors production order: open DB → migrate v0 → insert → migrate v1 → query → migrate v2 → query → … (see `imported_track_evolution_migration_e2e_test` / `imported_track_v0_to_v2_migration_e2e_test`).

## Success criteria

- After each migration step in the test, **reads used by the product** (identity fetch, list/recent, DSL-shaped queries) pass without schema mismatch or silent wrong defaults.
- New columns introduced in a step are visible in queries after that step; removed or absent-in-version fields are not required on earlier steps.

## Out of scope (unless amended)

- Cross-database vendors; downgrade migrations; blue/green multi-version readers on one physical DB.
