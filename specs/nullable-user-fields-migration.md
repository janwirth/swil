# Nullable user-defined columns (migration spec)

**Why:** User fields are emitted `NOT NULL`. SQLite rejects `ADD COLUMN ... NOT NULL` on a non-empty table without a default → breaks migrate v1 → insert → migrate v2 on the same `conn`.

**Rule:** `option.Option(_)` fields → nullable DDL + pragma `notnull = 0`. Keep `NOT NULL` on `id`, `created_at`, `updated_at`. `deleted_at` and FK columns unchanged.

**Acceptance (one `conn`):** Schema `{ name }` → migrate → insert row A → schema `{ name, age }` → migrate → insert row B. No errors. Row A: `name` intact, `age` NULL. Row B: `name` and `age` as inserted.

**Code:** `migration_sql.gleam` (`entity_ddl`, `build_create_table_sql`): drop `not null` on data fields. `migration.gleam`: `wanted_rows` notnull `0` for those fields. Fix blueprints/fixtures/tests (e.g. `case_studies/fruit_db/migration.gleam`).

**Caveat:** Nullable identity columns + `UNIQUE` → SQLite NULL semantics; enforce “required” in app if needed.
