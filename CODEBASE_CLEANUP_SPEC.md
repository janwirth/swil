# Codebase Cleanup Spec (Generator Style)

## Goal

Make generator modules consistent with the style used in `src/generator/crud_delete.gleam`.

Scope: all files in `src/generator/`, with priority on CRUD generators (`crud_filter`, `crud_update`, `crud_upsert`, and follow-up files).

## Required Style Rules

### 1) Use `gleamgen` APIs, avoid manual string assembly

- Build code through `gleamgen` constructs (`gex`, `gfun`, `gmod`, `gblock`, `gcase`, `gtypes`, `gpat`, `gparam`, `gim`).
- Do not generate source by concatenating string fragments for expressions, function bodies, modules, or SQL snippets.
- Keep output rendering centralized through `gleamgen_emit.render_module`.

Accepted:

- Composition with typed AST helpers and import/function builders.

Not accepted:

- `<>`-based source building for generated Gleam program structure.

### 2) Use `cake` builders, avoid raw SQL composition

- Build SQL with `cake` modules (`cake/update`, `cake/select`, `cake/insert`, `cake/where`, etc.) and convert with `to_query`.
- Prefer query-builder composition (table/set/where/order/limit) over raw SQL text.
- Execute through helper boundaries (for example `help/cake_sql_exec`) using decoded results.

Accepted:

- `cake_*` function references via `gim.function*`, then query composition via `gex.call*`.

Not accepted:

- String-built SQL statements (including interpolated SQL fragments) in generator logic.

### 3) Prefer `use` binding style to avoid deep nesting

- Use the pattern `use x <- call()` (or equivalent `gblock.with_use*` in generated expression composition) to flatten control flow.
- Prefer linear, composable blocks over deep nested `case`/`let` trees when behavior is equivalent.
- Use helper closures (for example `with_now_sec`) to isolate repeated binding flows.

Accepted:

- One-level continuation style with `use`-driven sequencing and small helper functions.

Not accepted:

- Deeply nested callbacks/anonymous functions when a `use` flow can represent the same steps.

### 4) Purge unused modules

- Remove generator modules that are no longer imported or referenced by active entry points.
- If a module is obsolete but may still be useful as a migration aid, move it to an explicit archive/experiments location instead of keeping it in active generator paths.
- Keep module graph minimal: one clear owner per responsibility, no dead duplicate implementations.

Accepted:

- Deleting unused modules after confirming no references remain.
- Consolidating duplicate logic into one canonical module.

Not accepted:

- Keeping dead modules in `src/generator/` "just in case".

### 5) Make private what can be private

- Default to private functions/types/constants; only mark public when used outside the defining module.
- Public surface in generator modules should be deliberate and minimal (typically just entry APIs such as `generate`).
- Reduce accidental API exposure to make refactors safer.

Accepted:

- Converting `pub fn` to `fn` when cross-module use is absent.
- Keeping internal helpers private even if heavily reused within a module.

Not accepted:

- Exposing helper symbols without an actual external consumer.

### 6) Run `gleam test` after every step

- After each cleanup step (including per-module edits, module removals, and visibility changes), run `gleam test`.
- Do not continue to the next step until tests pass for the current step.
- Treat failing tests as a blocker and fix before proceeding.

Accepted:

- Small, incremental edits with immediate `gleam test` validation.

Not accepted:

- Batched unverified refactors without intermediate test runs.

## Cleanup Plan

1. Audit each module in `src/generator/*.gleam` for:
   - string concatenation in generated code paths
   - raw SQL generation
   - avoidable deep nesting
   - unused module status (referenced vs dead)
   - unnecessary public symbols
2. Refactor each offender to:
   - `gleamgen` expression/type/function/module builders
   - `cake` query builder path
   - `use`-style flow flattening (`with_use*` or helper wrappers)
   - module deletion/consolidation when unused
   - private visibility by default for internal symbols
3. Keep behavior unchanged:
   - same function names and signatures
   - same query semantics and filters
   - same decode/result contract
4. For each deletion or visibility change, verify no downstream breakage in imports/calls.
5. After each step, run `gleam test` to validate the module and surrounding behavior.
6. Do not proceed to the next cleanup step until `gleam test` passes.

## Generator Module TODO Checklist

Mark each item when the module has been reviewed for all required style rules and refactored where needed.

**Status (as of current audit):**

- ✓ `crud_delete.gleam` - Reference style, fully compliant
- ✓ `crud_sort.gleam` - Uses gmod + gleamgen_emit; prepends one `import …/structure` line manually and omits `with_import` for that path so the import block is not duplicated when case arms and parameters both record `structure` in `used_imports`
- ✓ `crud_upsert.gleam` - Fully compliant (single `gleamgen_emit.render_module` + `gmod.with_import`; requires gleamgen `import_.new_with_exposing` and render rule for `exposing` imports)
- ✓ `crud_filter.gleam` - Full `gleamgen_emit.render_module` + `gmod` (imports, type alias, functions); cake via `gim` + `gex`
- ✓ `crud_read.gleam` - Full `gleamgen_emit.render_module` + `gmod` (imports, functions); `render_read_many_base_select_where` still renders one expression via `gex.render`
- ✓ `crud_update.gleam` - Full `gleamgen_emit.render_module` + `gmod.with_import` (folded field updates; `cake/select` via `import_.new_predefined`)
- ⚠ `crud.gleam` - Still uses `<>` for entire module (`gleamgen` drops `sqlight` when types are only in raw/custom fragments; anonymous `CatsDb` fields need label-preserving codegen)
- ✓ `entry.gleam` - Full `gleamgen_emit.render_module` + `gmod` (fixed upstream: `gleamgen` parameter render now merges `used_imports` from parameter types so `sqlight` is kept)
- ✗ `migration.gleam` - Uses `<>` for entire module
- ✓ `resource.gleam` - Full `gleamgen_emit.render_module` + `gmod` + `gcustom.with_dynamic_variants` + `gfun.new_raw`
- ✗ `structure.gleam` - Uses `<>` for entire module (largest remaining surface)

**Helper modules (no cleanup needed - they are utilities, not generators):**

- `full.gleam` - Orchestrator module, OK
- `gleam_format_helpers.gleam` - Helper module, OK
- `gleamgen_emit.gleam` - Helper module; `render_module` appends a trailing newline when the renderer omits one (keeps golden / POSIX text files stable)
- `gleamgen` (path dependency) - `parameter` render merges type `used_imports`; `module.render` dedupes import paths after `merge_imports` (see `crud_sort` note below)
- `schema_context.gleam` - Helper module, OK
- `sql_types.gleam` - Helper module, OK

**Priority order (CRUD generators first as per spec):**

1. [x] `crud_upsert.gleam` - Remove `<>` for header, use gmod for imports
2. [x] `crud_update.gleam` - Convert to full gleamgen style
3. [x] `crud_filter.gleam` - Convert to full gleamgen style
4. [x] `crud_read.gleam` - Convert module shell/imports to gleamgen (read query body already gleamgen)
5. [ ] `crud.gleam` - Still string-built (gleamgen prototype hit import-merge limits for `structure` + row type)
6. [x] `entry.gleam` - Migrated to `gleamgen_emit.render_module` (depends on gleamgen parameter `used_imports` fix)
7. [ ] `migration.gleam` - Still string-built (pending)
8. [x] `resource.gleam` - Migrated to `gleamgen_emit.render_module`
9. [ ] `structure.gleam` - Still string-built (pending; largest surface — custom types + decoder)

## Acceptance Criteria

- No new generator logic uses string concatenation for generated source structures.
- No new generator logic emits raw SQL strings where `cake` supports the query.
- Control flow in generators is flattened using `use` style wherever practical.
- No unused modules remain in active `src/generator/` paths.
- Module public API surface is minimized to externally consumed symbols only.
- `gleam test` passes after every cleanup step.
- Updated files remain readable and align with the `crud_delete` reference style.

## Reference

- `src/generator/crud_delete.gleam` is the baseline style reference.

## Instructions

Do not query the codebase excessively. All you need to know is in @src/generator. Don't think to much.
