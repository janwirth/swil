# Operations as pure data (replay and batch optimization)

## Goal

All database **operations** (insert, update, upsert, delete, and any bulk variants) should be expressible as **plain Gleam values** (algebraic types + data), not only as immediate side-effecting calls. That enables:

- **Replay**: the same value can be applied later, logged, or reapplied after failures without reconstructing closures or hidden state.
- **Batch processing**: a list of operations can be merged into fewer round-trips **without changing observable order**: same-type ops are grouped and executed as batches while the **overall sequence** of effects stays consistent with the input list (see below).
- **Testing**: golden fixtures of operation streams without live `Connection` in the core model.

## Rollout order (step by step)

Work proceeds in **three named stages** before any broad codegen rollout:

1. **Fruit** — **Start by reading** [`src/case_studies/fruit_schema.gleam`](src/case_studies/fruit_schema.gleam) (that file is the first schema you design against). Then implement against [`fruit_db`](src/case_studies/fruit_db/) as generated today. Smallest surface: prove `FruitCommand` + a **single** public executor `execute_fruit_cmds` (see **API sketch**).
2. **Hippos** — Same flow: **read** [`src/case_studies/hippo_schema.gleam`](src/case_studies/hippo_schema.gleam) first, then [`hippo_db`](src/case_studies/hippo_db/). Second entity with relationships and richer options; validates that the pattern holds beyond fruit.
3. **Human review** — Stop and review fruit + hippo APIs, naming, and tests **before** wiring the generator for every case study or expanding scope (chunking, serialization, etc.).

After stage 3, a follow-up step may **generalize** (codegen commands for all entities, docs). That step is intentionally not started until review is done.

## Principles

1. **Separation**
   - **Command**: pure description of intent, **one variant per distinct generated operation shape** (not only upsert/delete by declared `identities`).
   - **Executor**: `execute_*_cmds(conn, commands)` runs a list of commands (see **SQL is private**); optional thin `conn`-first wrappers may delegate here.

2. **No hidden inputs**  
   Commands carry every **business** parameter the executor needs (keys, payloads, flags). **`created_at` / `updated_at` are not stored on commands**; the executor injects them at **execution time** from the runtime (see **Decisions**).

3. **SQL is private**  
   Statement text and `sqlight.Value` binding lists are **implementation details** inside the entity module (or codegen private helpers). Callers only see **command values** and **`execute_*_cmds`**. Nothing public returns SQL strings or exposes the planner.

4. **Stable shape**  
   Command types are generated per schema (or per entity) alongside today’s `conn`-first APIs. Public fields remain labelled where the rest of the generated API uses labels.

5. **Compatibility**  
   Existing `fn(Connection) -> Result(...)` entry points may stay as thin wrappers that construct one command and call `execute_*_cmds(conn, [cmd])`, so current callers do not break in the first iteration.

## Batch optimization (non-goals vs goals)

**In scope for the spec (design hooks):**

- The executor (e.g. `execute_fruit_cmds(conn, commands)`) **preserves sequence** of the command list while **grouping by operation type** (same variant / same statement shape) and **running each group as one batch** (multi-row / multi-bind) where possible, instead of one round-trip per command.
- **Contiguous grouping** is the default: scan in list order, merge **runs** of identical op kinds into a single batch, flush when the kind changes—so cross-type ordering is never violated.
- Documented **ordering constraints** (e.g. foreign keys) for any future optimization that might batch non-contiguous same-type ops.

**Explicitly out of scope initially (unless amended):**

- Automatic chunking for SQLite parameter limits.
- Distributed or cross-process replay logs; file serialization format (JSON, etc.) can be a follow-up if command types are pure and `derive`-friendly where applicable.

## Command coverage (fruit example)

[`fruit_schema.gleam`](src/case_studies/fruit_schema.gleam) declares a single identity variant (`ByName`). The entity still has a **row `id`** (magic column) and generated APIs that target it—for example `update_fruit_by_id` / `get_fruit_by_id` in `fruit_db`.

**`FruitCommand` must include variants for both:**

- **Identity-keyed ops** — align with `FruitIdentities` / upsert–delete by natural key (e.g. `UpsertFruitByName`, `DeleteFruitByName`).
- **Extra ops by row id** — `<Op>FruitById` style variants for each SQL shape that uses `id` (e.g. `UpdateFruitById` with `id` + payload fields), even though `id` is **not** part of `FruitIdentities`.

Batching groups by **variant** (same constructor = same statement shape); `UpdateFruitById` and `UpsertFruitByName` are different batch lanes.

## API sketch (illustrative — fruit-shaped)

```gleam
// Illustrative — names follow codegen; fields match fruit_schema + magic id paths.
pub type FruitCommand {
  UpsertFruitByName(
    name: String,
    color: Option(String),
    price: Option(Float),
    quantity: Option(Int),
  )
  DeleteFruitByName(name: String)
  UpdateFruitById(
    id: Int,
    name: String,
    color: Option(String),
    price: Option(Float),
    quantity: Option(Int),
  )
}

/// **Only** public execution entry: applies `commands` in order, batching
/// consecutive **same-variant** runs internally.
/// On failure, the error carries the 0-based index of the first failing command.
/// Single op: `execute_fruit_cmds(conn, [cmd])`.
/// SQL and bindings are built **inside** this module — never exposed.
pub fn execute_fruit_cmds(
  conn: sqlight.Connection,
  commands: List(FruitCommand),
) -> Result(Nil, #(Int, sqlight.Error))
```

The important part is: **commands are pure data**; **one executor** per entity; **group-by-type batching** lives inside the executor; **callers never see SQL**.

## Relation to other specs

- **`OPTION_NONE_NULL_UNIQUE_SPEC.md`**: encoding of `Option` in command payloads must match the same NULL/sentinel/omit rules as direct APIs.
- **`UPSERT_API_REVAMP_SPEC.md`**: `by_<identity>(...)` row types are natural payloads inside upsert commands; phantom types for homogeneous batches should compose with command lists.

## Test requirements

- **Pure construction**: build a list of commands without a database; assert on equality or structural shape where useful.
- **Round-trip**: `execute_*_cmds` then read back via existing query APIs matches expectations for at least one case study entity.
- **Batch**: interleaved command types (`A, B, A` style) keep cross-type order; consecutive same-type ops (`A, A, A`) match repeated `execute_*_cmds(conn, [x])` vs one `execute_*_cmds(conn, [A, A, A])`.
- **Error index**: a failing command at index `N` returns `Error(#(N, _))`; for a batch of same-variant ops the index points to the first command of the failing batch. Preceding commands remain committed (no rollback).
- **Throughput**: benchmark `execute_fruit_cmds(conn, [A, A, A])` vs three separate `execute_fruit_cmds(conn, [A])` calls; the batched form must be measurably faster (validates per-group `BEGIN`/`COMMIT`).

## Decisions (locked)

| Topic | Decision |
|--------|-----------|
| **Variant visibility** | **Opaque** command types per entity. New operations require running the code generator—not open extension of the ADT by hand. |
| **Command ADT scope** | **Per-entity** command types only (e.g. `FruitCommand`, `HippoCommand`). No single mixed `AppCommand` ADT across entities—keeps modules and batching simple. |
| **Timestamps** | **`created_at` / `updated_at` are not fields on commands.** They are set at **execution time** inside `execute_*_cmds` (runtime). |
| **Atomicity** | **No wrapping transaction.** Upserts are idempotent; partial application is acceptable. Failed commands do not roll back preceding ones. |
| **Throughput** | `execute_*_cmds` is **synchronous** but must be fast. Each contiguous same-variant batch is wrapped in an explicit `BEGIN`/`COMMIT` — not for atomicity guarantees, but because SQLite auto-commits per statement otherwise (one fsync per row). WAL mode must be enabled on the connection before use. |
| **Error return** | On failure, return `Error(#(Int, sqlight.Error))` where the `Int` is the **0-based index** of the first failing command. When a batch of same-variant ops fails, report the index of the first command in that batch. |
| **ExecutionContext** | **No escape hatch.** No `ExecutionContext` type; no ambient-value mechanism. Commands are self-contained. |
| **Comments** | During development, all generated and hand-written executor code must carry **concise inline comments** explaining non-obvious decisions (batching logic, binding order, timestamp injection). Remove or trim once the pattern is stable. |

These are clear enough to implement: commands model **what** to change, not **when** the row was written.

## Implementation checklist (todos)

### Prerequisites

- [x] Decisions in **Decisions (locked)** agreed (opaque, per-entity, runtime timestamps, no atomicity guarantee, sync + per-batch transactions for throughput, error index, no ExecutionContext, concise comments during dev).

> **Note on alignment:** The fruit and hippo pilots intentionally make local choices on Option encoding and upsert payload types. Alignment with `UPSERT_API_REVAMP_SPEC.md` and `OPTION_NONE_NULL_UNIQUE_SPEC.md` is deferred to **Step 4 (generalize)** — not a prerequisite for piloting.

### Step 1 — Fruit (`fruit_schema.gleam` → `fruit_db`)

Pilot the full vertical slice on the smallest case study. **Read `fruit_schema.gleam` first**; commands must cover **every** generated op shape, including **`<Op>FruitById`** as well as **`ByName`** identity ops.

- [ ] `FruitCommand` (or codegen output): variants for identity-keyed APIs **and** row-`id` APIs (see **Command coverage (fruit example)**).
- [ ] Private planner (not public): map each variant to statement + bindings; inject timestamps here, not on command values.
- [ ] `execute_fruit_cmds(conn, commands)` — only public executor; contiguous same-variant batching inside; order preserved across variants; single op via `[cmd]`.
- [ ] Tests: pure construction, round-trip, batch equivalence, interleaved variants (see **Test requirements**).

### Step 2 — Hippos (`hippo_schema.gleam` → `hippo_db`)

**Read `hippo_schema.gleam` first**, then repeat the same pattern on a richer schema (relationships, more optionals). Include **identity-keyed** variants **and** any **`<Op>HippoById` (or magic-key)** shapes the generator emits, same rule as fruit.

- [ ] `HippoCommand` + private planner + `execute_hippo_cmds(conn, commands)` only (same surface as fruit).
- [ ] Tests mirroring fruit; add at least one scenario that stresses ordering or shape differences vs fruit (e.g. multiple op variants, FK-related ordering if applicable).

### Step 3 — Human review

- [ ] Review fruit + hippo public API names, module layout, and test coverage.
- [ ] Explicit sign-off (or issue list) before **Step 4**.

### Step 4 — Generalize (after review)

- [ ] Extend code generation so other case studies / entities get commands without hand-copying the fruit/hippo pilot.
- [ ] Refactor existing `conn`-first APIs to build a command and delegate to `execute_*_cmds` where desired.
- [ ] Short developer note (README or guide): pass one command as `[cmd]` vs many; batching is automatic inside `execute_*_cmds`.
- [ ] Track out-of-scope items (parameter-limit chunking, serialization) for a later spec if needed.

