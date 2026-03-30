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

Migrations

- No migration versioning.

Ensure the following

1. **Regen and stability** — For every case-study module, run `gleam run -- src/case_studies/<module>`, then `gleam test`. Stable means: working tree has **zero diff** after regeneration, all tests pass, and the build emits **no warnings**.
2. **Speed** — `gleam test` must finish in **under 500ms** wall time. New tests must not push the suite over that budget.
3. **Generators** — No module-specific hard-coding; abstract over module name and drive behavior from schema / shared IR, not ad hoc branches for one case study.
