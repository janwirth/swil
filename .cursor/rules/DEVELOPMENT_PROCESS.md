---
globs:
alwaysApply: true
---

Development process

1. Pinpoint new requirements in the generated code (`{module_name}_db`) or schema, as driven by the spec for the task. What must change follows the spec—not a fixed checklist every time.
2. Add tests where applicable. The suite is already well structured; extend it in the same style. Minimum bar when the feature applies:
   - one e2e test
   - a DB structural test
   - DSL / parser coverage for the language constructs involved
   Skip layers that are not relevant to the change.
3. Implement the requirement along the same pipeline as today (parser, schema types, migrations, generators)—only the parts the spec touches.

Source of truth

- The task defines the source of truth. It moves from the natural starting points (schema, IR, spec) through the codebase; do not invent a second authority (e.g. hand-edited generated output as truth).

Documentation

- Prefer self-documenting code: names, types, and structure should carry intent thoroughly. Do not add separate markdown docs for routine changes; the code is the documentation.
- Public functions must use labelled arguments for all consumer-facing parameters (except intentionally unlabelled ones such as `conn` where established).

Control flow

- Avoid deep callback nesting: prefer the **`use` continuation style** for sequential steps that would otherwise be `f(fn() { g(fn() { h(...) }) })`. Examples: `use x <- result.try(expr)` for `Result` pipelines (see `src/swil.gleam` `generate_from_schema_path`), and `use _ <- gmod.with_import(...)` / `use _ <- gmod.with_function(...)` when assembling gleamgen modules. Extract a named helper when a block needs both `use` and non-trivial logic.

Migrations

- No migration versioning.

Code generation

- **gleamgen** is the default mode: build Gleam source through the gleamgen AST and renderer. New or refactored emitters use gleamgen; do not introduce ad hoc string-concatenation generators unless the task explicitly requires it.

Ensure the following

1. **Regen and stability** — For every case-study module, run `gleam run -- src/case_studies/<module>`, then `gleam test`. Stable means: working tree has **zero diff** after regeneration, all tests pass, and the build emits **no warnings**.
2. **Speed** — `gleam test` must finish in **under 500ms** wall time. New tests must not push the suite over that budget.
3. **Generators** — Follow the gleamgen default (above). No module-specific hard-coding; abstract over module name and drive behavior from schema / shared IR, not ad hoc branches for one case study.
