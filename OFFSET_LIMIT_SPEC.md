# Offset + limit (generated list queries)

**Spec only.** Pagination for the same row set as `last_100_edited_*`: non-deleted rows, `order by "updated_at" desc`, full returning columns—plus schema DSL and parser rules that **must** land before or with codegen.

## SQL (canonical emission)

```sql
select … from "table"
where "deleted_at" is null
order by "updated_at" desc
limit ? offset ?;
```

Bind order: `limit` first, `offset` second (SQLite `LIMIT n OFFSET m`). **Codegen always emits clauses in this order**, regardless of how the Gleam pipeline was written.

## DSL naming

- Use **`dsl.order_by(field, direction)`** — not `dsl.order`.
- Windowing: **`dsl.limit(limit: n)`** and **`dsl.offset(offset: n)`** (labelled args at the stub; parser accepts the same shapes the typechecker does).

## Phantom types (`swil/dsl`)

- After `dsl.query(root)`, each pipeline step has its own **open / closed** slot: `shape`, `filter` (`filter_bool` / `filter` / `filter_complex` share one filter slot), `order_by`, `limit`, `offset`.
- **At most once per slot** — a second call to the same step is a **compile-time** error (incompatible phantom parameters).
- Steps may appear in **any source order** that still typechecks (e.g. `filter_bool` before `shape` is allowed if the API permits it).

## Parser (`schema_definition/query`)

- **No fixed pipeline template.** Treat the tail as `dsl.query(..)` followed by a sequence of `|> dsl.<step>(..)` segments.
- Each recognized step name may appear **0 or 1 times**. A duplicate → **`ParseError`** with a clear message.
- **Unknown** `dsl.*` step in the chain → **`ParseError`** (do not silently ignore).
- **`dsl.order`** in source → reject with a hint to use **`dsl.order_by`**.
- **Optional pieces:** omitting `order_by` may default IR to `UpdatedAtDesc` (same idea as `order_by(option.None, ..)` today); omitting `shape` may default to full-entity / `NoneOrBase`—only if that matches existing IR semantics; document in parser when implemented.
- **`limit` / `offset` in `query_*` bodies:** parse and store in IR when ready; until SQL gen exists, may error with “not implemented yet” rather than dropping them silently.
- **Nested-call form** (outer `order_by(filter_*(shape(query(..))…), field, dir)`) remains supported if we keep it; must use **`order_by`**, not `order`.

## Schema (pseudocode)

Illustrative order only—**any valid permutation** of the steps above is allowed if types and parser agree.

```gleam
pub fn query_cheap_fruit_page(
  fruit: Fruit,
  _magic_fields: dsl.MagicFields,
  max_price: Float,
  limit: Int,
  offset: Int,
) {
  dsl.query(fruit)
  |> dsl.shape(fruit)
  |> dsl.filter_bool(dsl.exclude_if_missing(fruit.price) <. max_price)
  |> dsl.order_by(fruit.price, dsl.Asc)
  |> dsl.limit(limit: limit)
  |> dsl.offset(offset: offset)
}
```

**IR note:** extra parameters (`max_price`, `limit`, `offset`) may require extending `QueryFunctionParameters` / bind slots beyond a single “simple” parameter.

## Generated API (entity CRUD)

- **New** per entity: `page_edited_<entity>(conn, limit limit: Int, offset offset: Int) -> Result(List(#(Entity, dsl.MagicFields)), sqlight.Error)` (gleamgen; labelled args).
- **Keep** `last_100_edited_<entity>(conn)`; thin wrap to `page_edited_*` with `limit: 100, offset: 0` or keep literal SQL—either is fine if regen is stable and behavior matches.

## Semantics

- `limit = 0` → zero rows (SQLite).
- `offset = 0` → first page.
- Callers pass **non-negative** `limit` and `offset` in v1 tests; invalid values follow SQLite.

## Examples (generated API)

```gleam
let assert Ok(rows) = api.page_edited_fruit(conn, limit: 10, offset: 0)
let assert Ok(rows) = api.page_edited_fruit(conn, limit: 10, offset: 10)
let assert Ok(rows) = api.last_100_edited_fruit(conn)
```

## Generator pipeline (gleamgen)

1. **`api_sql`**: `page_edited_sql(table, returning_cols)` (or shared helper).
2. **`api_crud_bodies`**: `sqlight.query(..., with: [sqlight.int(limit), sqlight.int(offset)], ...)`.
3. **`api_chunks` / `api`**: const + `page_edited_<entity>` beside `last_100_edited_*`; no case-study–specific branches.
4. **`api_facade`**: re-export if applicable.

## Tests (minimum)

| Layer            | What                                                                                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Structural**   | Generated SQL const contains `limit ?` and `offset ?` in bind order.                                                                                      |
| **E2E**          | ≥5 rows, distinct `updated_at`; `page_edited_*` with `limit: 2, offset: 2` matches the expected `updated_at desc` slice.                              |
| **DSL / parser** | Duplicate `dsl.shape` / double `order_by` rejected; flexible order of steps parses to the same IR; `dsl.order` rejected with `order_by` hint; optional. |

## Non-goals (v1)

- `COUNT(*)` / total rows.
- Keyset / cursor pagination.
- Arbitrary `order by` / filters on the **generated** `page_edited_*` (stay aligned with `last_100_edited_*`); custom queries stay in `query_*` + IR.

---

## Implementation todo

Use this as the merge checklist; order can overlap where noted.

- [x] **Spec** — keep this file the source of truth; link from PR / task if needed.
- [x] **`swil/dsl`** — `order` → `order_by`; add `limit` / `offset` stubs; phantom slots so each step is **single-use**; allow flexible **compile-time** step order per matrix above.
- [x] **Schemas / guides / README** — replace `dsl.order` with `dsl.order_by` everywhere examples exist.
- [x] **`schema_definition` IR** — extend `Query` (or adjacent type) for optional `limit` / `offset` expressions when schema queries need them.
- [x] **Parser** — flexible `|>` chain: 0–1× per step, duplicates error; `order` → hint; nested `order_by(...)` form updated; optional defaults for missing `shape` / `order_by` aligned with IR.
- [ ] **`query_params` / validation** — extend when `query_*` gains more than one simple bind.
- [x] **Generators** — `api_sql`, `api_crud_bodies`, `api_chunks`, `api`, `api_facade` for `page_edited_*`; wire schema query SQL when IR has limit/offset.
- [x] **Regen** — `gleam run -- test/case_studies/<module>` for each case study, then `gleam test`; **zero diff** after regen, **no warnings**, suite under **500ms** wall time (see `.cursor/rules/DEVELOPMENT_PROCESS.md`).
- [x] **Tests** — structural + e2e + parser cases from the table above.
