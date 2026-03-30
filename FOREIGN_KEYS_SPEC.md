# Foreign keys (pragma + DDL)

Companion to [`CONNECTION_SUGAR.md`](CONNECTION_SUGAR.md). **Spec only.**

## Per-connection pragma

SQLite disables foreign-key enforcement by default (`foreign_keys` off). Every app connection should run:

```sql
PRAGMA foreign_keys = ON;
```

Without this, `FOREIGN KEY` / `REFERENCES` in DDL are ignored at runtime.

## State of **skwil** codegen (investigation)

- **Generators and case-study DB code** do not set `PRAGMA foreign_keys` today; tests and apps use `sqlight.open(...)` without this pragma.
- **Emitted DDL** (entity tables + junction tables) uses integer columns (e.g. `trackbucket_id`, `tag_id`) and unique indexes, but **does not** emit SQL `FOREIGN KEY (...)` or `REFERENCES` clauses.
- Turning **`foreign_keys = ON`** is therefore **correct and future-proof** but **changes nothing** until migrations actually declare FK constraints.
- Product follow-ups (see [`tasks/TRIAGE.md`](tasks/TRIAGE.md)): relationship/FK assignment in API layer, pragma auto-enable on connect, optional DDL that adds real `REFERENCES`.

## When you add real FKs in DDL

- Keep **`PRAGMA foreign_keys = ON`** on every connection (including pooled / reopened handles).
- Order migrations so parent rows exist before children, or use `DEFERRABLE INITIALLY DEFERRED` if you batch inside one transaction (SQLite supports deferrable FKs in recent versions for checked builds).
- Large batched writes (see connection sugar spec) still apply: one transaction + many statements beats thousands of commits; long transactions block the single writer—balance batch size vs hold time.

## Non-goals here

- Exact migration grammar for `REFERENCES` (entity graphs, cascades, partial FKs).
- Cross-database or `ATTACH` FK behavior.
