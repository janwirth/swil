# Query Parsing + Codegen Spec (v2)

## Goal

Define a strict, parse-time validated query model for schema query functions and remove legacy `QueryCodegen` pattern tags (`LtMissingFieldAsc`, `EqMissingFieldOrder`, `Unsupported`).

## Scope

- Source of truth is `schema_definition.SchemaDefinition.QuerySpecDefinition.query`.
- Query generation must read this structured `Query` model directly.
- Generated relationship query functions for hippo must live in `src/case_studies/hippo_db/query.gleam`.
- Fruit query generation stays correct and unchanged in behavior.

## Query Model

- `Query(shape: Shape, filter: Option(Filter), order: Order)`
- `Shape`
  - `NoneOrBase` means full base entity row.
  - `Subset(selection: List(SelectionPath))` means projected shape.
- `SelectionPath(fields: List(String))`
  - Represents path segments from root entity through optional relationships.
- `Filter`
  - `NoFilter`
  - `BooleanFilter(left_operand_field_name, operator, right_operand_parameter_name, missing_behavior)`
- `MissingBehavior`
  - `ExcludeIfMissing`
  - `Nullable`
- `Operator`
  - `Lt | Eq | Gt | Ne | Le | Ge`
- `Order`
  - `UpdatedAtDesc`
  - `CustomOrder(field, direction)`

## Strictness Rules (Parse-Time Hard Errors)

- Public query functions must remain tightly constrained.
- Unsupported query constructs are parse errors, not deferred to generation.
- No fallback `Unsupported` variant in parsed query specs.
- If parser cannot map function body to supported `Query` structure, parsing fails.

## Defaults

- Default shape is full base entity row (`Shape.NoneOrBase`).
- If query syntax omits or cannot safely resolve a custom shape, parser must either:
  - resolve to `NoneOrBase` when valid by contract, or
  - fail with parse error when ambiguous/unsupported.

## Codegen Contract

- Generators consume `QuerySpecDefinition.query` only.
- Remove any branching on legacy `codegen` tags.
- SQL/query function emission must be deterministic from:
  - parsed `shape`
  - parsed `filter`
  - parsed `order`
- Generated hippo relationship-query functions are emitted in `hippo_db/query.gleam` (not `relationship_queries.gleam`).

## Migration/Cleanup

- Remove legacy codegen-specific types and inference plumbing.
- Remove dead code and stale helpers tied only to old tags.
- Keep module responsibilities tidy and obvious after migration.

## TODO List

- [ ] Remove legacy `QueryCodegen` variants and all `spec.codegen` branching.
- [ ] Parse `dsl.filter(...)` into `Filter.BooleanFilter` with `MissingBehavior`.
- [ ] Keep unsupported query constructs as hard parser errors.
- [ ] Keep default `Shape.NoneOrBase` as full base entity row.
- [ ] Emit generated hippo query helpers in `src/case_studies/hippo_db/query.gleam`.
- [ ] Remove `src/case_studies/hippo_db/relationship_queries.gleam` usage paths.
- [ ] Keep `src/case_studies/fruit_db/query.gleam` output unchanged in behavior.
- [ ] Update tests/snapshots and remove stale query-codegen expectations.

## Acceptance Criteria

- `schema_definition/query.gleam` no longer exposes legacy codegen tags.
- Parser returns `QuerySpecDefinition` with structured `Query` and hard-errors on unsupported syntax.
- `hippo_db/query.gleam` contains generated query functions needed by hippo schema queries.
- `fruit_db/query.gleam` remains behaviorally correct for `query_cheap_fruit`.
- Tests for API generation and query behavior pass after cleanup.
