# Upsert API Revamp

## Target API

```gleam
api.upsert_one(conn, api.by_x_and_y(...))
```

```gleam
let items = my_items
  |> list.map(fn(item) { api.by_x_and_y(...) })
api.upsert_many(conn, items)
```

## Spec

- Replace `upsert_*_by_*` with two entry points per entity:
  - `upsert_one(conn, row)`
  - `upsert_many(conn, rows)`
- Generate constructor helpers for each identity variant:
  - `by_<identity>(...)`
- `by_<identity>(...)` returns a typed row payload consumable by both `upsert_one` and `upsert_many`.
- All public generated function args remain labelled (except existing intentional exceptions like unlabelled `conn`).
- Keep implementation generic from schema/IR (no module-specific branching).

## Decisions

- Should `upsert_many` execute one statement per row, or emit grouped multi-row SQL by identity variant?
  - multi-row insert into value statements
- Should `upsert_many` be fully atomic (single transaction) by default?
  - yes
- If mixed identity variants are passed in one list, do we allow it or require homogeneous batches?
  - allow only one, because only then it works with on conflict targeting a specific index. use phantom types to enforce
- Do we expose one shared row type per entity, or one row constructor type per identity variant?
  - one per identity variant
- Should old `upsert_*_by_*` APIs be removed immediately, or temporarily forwarded with deprecation?
  - kill it with fire.

- How do we chunk very large `upsert_many` batches to avoid SQLite parameter limits?
  - out of scope
- What is the expected return ordering for `upsert_many` when using batched SQL (`RETURNING` ordering guarantees)?
  - count only (ordering not guaranteed)
- How should duplicate identities inside one batch behave (last wins, first wins, or explicit error)?
  - out of scope
- Do we expose conflict policy knobs now (upsert/update-only/insert-only), or keep a single default behavior?
  - just the upsert behavior as before, we only have upsert
- Do we support partial failure reporting for `upsert_many`, or keep fail-fast whole-batch semantics only?
  - fail fast
- Should generated `by_<identity>` constructors include compile-time safeguards against invalid empty identity inputs?
  - yes, phantom type. Try sth like the below:

```gleam
// phantom type example
pub opaque type ByName {}

pub opaque type ByFruit {}

pub opaque type MyFruit(id) {}

pub fn insert(fruit: MyFruit(Identified(id))) {

}


```

## Test Requirements

Codegen tests (required):

- Generated API must include only `upsert_one` and `upsert_many` (no `upsert_*_by_*` public fns).
- Generated constructors must include one `by_<identity>` helper per identity variant.
- Generated constructor payload types must be identity-specific (one type per identity variant).
- Generated public function params must remain labelled for consumer-facing args.
- Generated SQL for `upsert_many` must use multi-row `insert into ... values (...), (...)` with `on conflict`.

E2E tests (required):

- Insert at least 3 rows via `upsert_many` using `by_<identity>` constructors.
- Verify rows are persisted and retrievable through generated `get`/`query` APIs.
- Verify atomicity: one invalid row causes whole batch rollback when `upsert_many` runs in a single transaction.
- Verify duplicate identities within one batch follow the chosen policy.
- Verify mixed-identity input is rejected at compile time (preferred) or runtime with explicit error.

## Todo (implementation order)

1. Define new schema IR/codegen model for identity-specific upsert input types.
2. Implement generator output for:
   - `upsert_one`
   - `upsert_many`
   - `by_<identity>` constructors
3. Remove legacy `upsert_*_by_*` exports from generated `upsert` and `api` modules.
4. Implement batched multi-row SQL generation and single-transaction execution for `upsert_many`.
5. Add/upgrade codegen tests for API surface, constructors, and emitted SQL.
6. Add/upgrade e2e tests in at least one case-study module with 3+ row batch coverage and rollback checks.
7. Regenerate all case-study outputs and update snapshots/fixtures.
8. Run full `gleam test` and ensure no warnings on build.
