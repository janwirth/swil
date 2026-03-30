# Triage

The idea is to evolve tasks into full specs to hand them off to agents for execution.

## Review checklist

Tick each row when the short description matches what you want the eventual spec to cover. Edit the text before promoting a row to a full task spec.

- [ ] **Load / perf testing** — Automated load testing over many queries: DB should sustain ~100k ops/s without issue on large databases (e.g. ~100k rows per relevant table). Goal is to catch missing optimizations early; add a harness when we commit to this bar.

- [ ] **SQL escape hatch** — Allow emitting or embedding raw SQL where the typed API cannot express a query, with clear safety boundaries (parameters, scope, naming).

- [ ] **Documentation of syntax** — Document the schema/migration/API surface syntax users and codegen rely on (grammar, examples, edge cases).

- [ ] **Set relationship value** — API/codegen to assign or clear foreign-key (or equivalent) relationship fields when creating or updating rows.

- [ ] **ON DELETE CASCADE** — Model and migrate FK behavior so related rows are deleted (or restricted) according to schema; surface in types/migrations.

- [ ] **Database ID hardcoded into schema** — Represent a stable per-database or per-deployment identifier in the schema layer for migrations, multi-db, or tooling.

- [ ] **Union types + shared fields** — Model with Gleam unions: a `SharedFields` record (or constructor payload) holds columns common to every variant (e.g. track `source` with `source_id`); each variant adds its own fields. Prefer this over strings or opaque ints alone for those domains.

- [ ] **Auto-enable pragma and import extensions** — When opening or migrating SQLite, automatically set required pragmas and load extensions the schema/runtime depends on.
