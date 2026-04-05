# Operations as pure data (replay and batch optimization)

## Goal

All database **operations** (insert, update, upsert, delete, and any bulk variants) should be expressible as **plain Gleam values** (algebraic types + data), not only as immediate side-effecting calls. That enables:

- **Replay**: the same value can be applied later, logged, or reapplied after failures without reconstructing closures or hidden state.
- **Batch processing**: a list of operations can be merged into fewer round-trips **without changing observable order**: same-type ops are grouped and executed as batches while the **overall sequence** of effects stays consistent with the input list (see below).
- **Testing**: golden fixtures of operation streams without live `Connection` in the core model.

## Principles

1. **Separation**  
   - **Command**: pure description of intent (`UpsertTrackById { ... }`, `DeleteFruit { id = ... }`, etc.).  
   - **Interpreter**: functions that take `Connection` (and maybe transaction context) and execute one or many commands.

2. **No hidden inputs**  
   Commands carry every parameter needed to build SQL and bindings (timestamps policy should be explicit: either embedded in the command or supplied by a single `ExecutionContext` value that is also plain data).

3. **Stable shape**  
   Command types are generated per schema (or per entity) alongside today’s `conn`-first APIs. Public fields remain labelled where the rest of the generated API uses labels.

4. **Compatibility**  
   Existing `fn(Connection) -> Result(...)` entry points may stay as thin wrappers that construct the command and call the interpreter, so current callers do not break in the first iteration.

## Batch optimization (non-goals vs goals)

**In scope for the spec (design hooks):**

- A batched runner (e.g. `run_batched(conn, commands, opts)`) that **preserves sequence** of the command list while **grouping by operation type** (same variant / same SQL statement shape) and **executing each group as one batch** (multi-row or multi-bind), instead of one round-trip per command.
- **Contiguous grouping** is the default: scan in list order, merge **runs** of identical op kinds into a single batch, flush when the kind changes—so cross-type ordering is never violated.
- Documented **ordering constraints** (e.g. foreign keys) for any future optimization that might batch non-contiguous same-type ops.

**Explicitly out of scope initially (unless amended):**

- Automatic chunking for SQLite parameter limits.
- Distributed or cross-process replay logs; file serialization format (JSON, etc.) can be a follow-up if command types are pure and `derive`-friendly where applicable.

## API sketch (illustrative, not final)

```gleam
// Illustrative names — actual names come from codegen.
pub type FruitCommand {
  UpsertFruitByName(name: String, ripeness: Option(Int))
  DeleteFruitByName(name: String)
}

/// One command → one statement + bindings (pure).
pub fn fruit_command_to_sql(cmd: FruitCommand) -> #(String, List(sqlight.Value))

/// No batching: one round-trip per command, order preserved.
pub fn run_fruit_command(
  conn: sqlight.Connection,
  cmd: FruitCommand,
) -> Result(Nil, sqlight.Error)

/// Batching: **sequence of effects matches `commands` order**, but consecutive
/// commands of the **same variant** are **grouped** and executed as one batch
/// (fewer `query` calls). Optimization lives here—not in `run_fruit_command`.
pub fn run_fruit_commands_batched(
  conn: sqlight.Connection,
  commands: List(FruitCommand),
) -> Result(Nil, sqlight.Error)
```

The important part is: **constructors are pure**; execution is separate; **group-by-type batching** is centralized in the list runner so single-command and replay paths stay simple.

## Relation to other specs

- **`OPTION_NONE_NULL_UNIQUE_SPEC.md`**: encoding of `Option` in command payloads must match the same NULL/sentinel/omit rules as direct APIs.
- **`UPSERT_API_REVAMP_SPEC.md`**: `by_<identity>(...)` row types are natural payloads inside upsert commands; phantom types for homogeneous batches should compose with command lists.

## Test requirements

- **Pure construction**: build a list of commands without a database; assert on equality or structural shape where useful.
- **Round-trip**: `command → run → query` matches expectations for at least one case study entity.
- **Batch**: interleaved command types (`A, B, A` style) keep cross-type order; consecutive same-type ops (`A, A, A`) match sequential `run_fruit_command` after `run_fruit_commands_batched`.

## Decisions (to fill in during review)

- Opaque vs public command variants for extensibility?
- Single `AppCommand` ADT vs per-entity command types only?
- Whether timestamps (`created_at` / `updated_at`) live on the command or are injected only at execution time?

## Implementation checklist (todos)

### Phase 0 — Lock design

- [ ] Resolve open questions under **Decisions** (command ADT shape, timestamp ownership).
- [ ] Align with **`UPSERT_API_REVAMP_SPEC.md`** on row / identity payload types for upsert commands.
- [ ] Align with **`OPTION_NONE_NULL_UNIQUE_SPEC.md`** on `Option` encoding inside command payloads.

### Phase 1 — Command types and pure SQL planning

- [ ] Add codegen (or hand-written pilot for one case study) for `*Command` ADT per entity / per op variant.
- [ ] Implement `command_to_sql` (or equivalent) returning statement + bindings with **no** `Connection`.
- [ ] Document timestamp policy: embedded on command vs injected via `ExecutionContext`.

### Phase 2 — Interpreter and compatibility

- [ ] Implement `run_*_command(conn, cmd)` as execute of planned SQL (single round-trip).
- [ ] Refactor existing public `conn`-first APIs to build commands and delegate to the interpreter (or document deferral).
- [ ] Ensure labelled parameters match existing generated API conventions.

### Phase 3 — Batched runner (contiguous grouping)

- [ ] Implement list segmentation: maximal runs of the same variant in input order.
- [ ] Map each run to one batched SQL execution (multi-row / multi-bind as appropriate).
- [ ] Verify cross-variant order: interleaved `A, B, A` executes as three batches in that order.

### Phase 4 — Tests

- [ ] **Pure**: construct command lists without DB; assert structure / equality where useful.
- [ ] **Round-trip**: `run_command` then read back via existing query APIs (one case study minimum).
- [ ] **Batch equivalence**: `run_*_commands_batched` vs sequential `run_*_command` for consecutive same-type runs.
- [ ] **Interleaved**: mixed variant list preserves observable order vs naive sequential execution.

### Phase 5 — Docs and follow-ups

- [ ] Short developer note in README or guide: when to use batched vs single command.
- [ ] Track out-of-scope items (parameter-limit chunking, serialization) for a later spec if needed.

## Note

The original prompt ended mid-sentence (“They …”). This file captures the stated intent (replay + batch optimization via pure data). Extend this section if you had a further requirement (e.g. serialization, event sourcing, or CRDT-style merge).
