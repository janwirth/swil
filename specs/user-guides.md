# User guides — documentation map

**Purpose:** Ordered, hands-on cases under `src/guide/<case>/`. Each case is a **folder** with two docs:

- **`_schema.md`** — what to put in your `*_schema.gleam` (types, identities, relationships, query specs) and why.
- **`_usage.md`** — follow-along from **authoring → generation → SQLite connection → migrate → runtime API** (CRUD, queries, etc.), in numbered steps.

Implementation details and fuller examples stay in `case_studies/` and the root README; guides stay copy-paste friendly and linear.

**Convention for `_usage.md` steps (every case):**

1. Create or edit the schema module described in `_schema.md`.
2. Run the Swil CLI against that module (same pattern as root README: `swil <schema_module_name>` from the package root).
3. Confirm generated `*_db/` output (`migration.gleam`, `api.gleam`, `query.gleam`, `row.gleam`, …).
4. Open an `sqlight.Connection` in your app or test.
5. Call `migrate(conn)` once per connection before reads/writes.
6. Exercise the operations the case introduces (CRUD, generated queries, `last_100_edited_*`, …).

Read cases in order; later cases assume earlier ones.

---

1. **`src/guide/01-foundations/`** — User field types (scalars, `option`, enums, dates), `identities` as upsert/delete keys, built-in magic fields (`id`, `created_at`, `updated_at`, `deleted_at`) and `MagicFields` beside row types. `_usage.md`: first full generate → migrate → upsert/get/delete path.

2. **`src/guide/02-built-in-operations/`** — Everything you get without custom query functions: migrate semantics at a high level, generated CRUD naming from identities, `last_100_edited_<entity>` (non-deleted, `updated_at` desc, limit 100). `_usage.md`: evolve schema, re-run generator, migrate again on the same DB.

3. **`src/guide/03-queries/`** — User-defined query functions: `dsl.query`, `shape`, `filter`, `order`; how they land in `*_db/query.gleam`. `_usage.md`: add a query spec, regenerate, migrate if needed, call the new query from Gleam.

4. **`src/guide/04-relationships/`** — Relationship types (belongs-to, backlinks, mutuals), junction attributes, magic fields on edges. `_usage.md`: multi-entity migrate order, upserts across FKs, relationship-aware reads.

5. **`src/guide/05-advanced-queries/`** — Heavier query shapes (computed fields, nullable relationship navigation, multi-condition filters). `_usage.md`: extend schema + query specs, regenerate, migrate, run advanced query functions.
