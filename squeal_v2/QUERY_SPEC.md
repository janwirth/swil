# Query Parsing + Codegen Spec (v2)

## Goal

Use a single structured query model (`QuerySpecDefinition.query`) across parsing and codegen, replacing legacy query-codegen tags while keeping generation behavior stable for existing case studies.

## Non-Negotiable Constraints

- No hard-coded module-specific generation logic.
  - Generators must not special-case modules like `fruit_schema`, `hippo_schema`, or any specific case-study path.
  - All parse/codegen behavior must derive from the schema AST/model only.
- No consumer-written custom SQL required.
  - Consumers define queries only through schema DSL/query functions.
  - Generated modules must emit SQL from the parsed query model.
  - Unsupported query shapes must be handled by expanding parser/model/codegen support, not by asking the consumer to hand-write SQL.
- No hidden fallback that silently relies on manual query modules.
  - If a query is declared in schema, generation is expected to either support it directly or fail with an explicit, actionable parser/codegen error.

## Current Contract

- Source of truth: `schema_definition.SchemaDefinition.QuerySpecDefinition.query`
- Query shape:
  - `Query(shape: Shape, filter: Option(Filter), order: Order)`
  - `Shape.NoneOrBase` means full base entity row
  - `Shape.Subset(selection: List(SelectionPath))` reserved for projected row support
- Filter shape:
  - `NoFilter`
  - `BooleanFilter(left_operand_field_name, operator, right_operand_parameter_name, missing_behavior)`
  - `MissingBehavior = ExcludeIfMissing | Nullable`
- Ordering:
  - `UpdatedAtDesc`
  - `CustomOrder(field, direction)`

## Implemented Behavior (As Of Now)

- Parser emits `QuerySpecDefinition(..., query: Query)` (no legacy `spec.codegen` in public model).
- Generator consumes `spec.query` for query SQL/function generation.
- Parser now emits expression-based query nodes:
  - `ShapeItem(alias, expr)` for tuple projections
  - `Predicate(Compare(...))` / `And` / `Or` / `Not`
  - `CustomOrder(expr, direction)` where `expr` can be computed
- `MissingBehavior` is inferred from expression trees:
  - `exclude_if_missing(...)` -> `ExcludeIfMissing`
  - `nullable(...)` -> `Nullable`
- `hippo_db/query.gleam` and `fruit_db/query.gleam` are generated from schema and match snapshot tests.
- Full test suite currently passes in this branch.

## Parsing Rules

- Public `query_*` functions still must conform to the 3-parameter contract:
  - `(entity, dsl.MagicFields, simple)`
- Supported parser forms now include:
  - `shape(entity)` and tuple projection `shape(#(...))` with auto-derived aliases when unambiguous
  - computed expressions in shape/filter/order for whitelisted functions (`exclude_if_missing`, `nullable`, `age`)
  - `filter(option.None)` and `order(option.None)` as explicit no-filter/default-order forms
- Query bodies outside the supported AST are explicit parser errors (no compatibility fallback).

## Unsupported Matrix (Strict Errors)

The following are currently **not** represented and fail at parse time with actionable errors:

- Non-whitelisted functions in query expressions.
- Calls with unsupported arity/argument forms.
- Field-access forms that cannot be represented in `Expr`.
- Operators outside the supported comparison set.

### Where You Can See Each Unsupported Pattern

- Complex shape projection with computed + relationship value
  - File: `src/case_studies/hippo_schema.gleam`
  - Function: `query_old_hippos_owner_emails`
  - Example:
    - `dsl.shape(#(#("age", age(exclude_if_missing(hippo.date_of_birth))), nullable(hippo.relationships.owner).item.email))`
- Same unsupported shape/filter/order pattern repeated in sibling query
  - File: `src/case_studies/hippo_schema.gleam`
  - Function: `query_old_hippos_owner_names`
  - Example:
    - `dsl.shape(#(#("age", age(exclude_if_missing(hippo.date_of_birth))), nullable(hippo.relationships.owner).item.email))`
- Computed filter expression (`age(...) > min_age`)
  - File: `src/case_studies/hippo_schema.gleam`
  - Functions: `query_old_hippos_owner_emails`, `query_old_hippos_owner_names`
  - Example:
    - `dsl.filter(age(exclude_if_missing(hippo.date_of_birth)) > min_age)`
- Computed order expression (`order_by(age(...), Desc)`)
  - File: `src/case_studies/hippo_schema.gleam`
  - Functions: `query_old_hippos_owner_emails`, `query_old_hippos_owner_names`
  - Example:
    - `dsl.order(dsl.order_by(age(exclude_if_missing(hippo.date_of_birth)), dsl.Desc))`
- `nullable(...)`-driven operand (no dedicated `MissingBehavior.Nullable` inference yet)
  - File: `src/case_studies/hippo_schema.gleam`
  - Functions: `query_old_hippos_owner_emails`, `query_old_hippos_owner_names`
  - Example:
    - `nullable(hippo.relationships.owner).item.email`

### Supported Baseline You Can Compare Against

- Fully supported simple pattern (`exclude_if_missing` + simple comparison + field order)
  - File: `src/case_studies/fruit_schema.gleam`
  - Function: `query_cheap_fruit`
  - Example:
    - `dsl.filter(dsl.exclude_if_missing(fruit.price) <. max_price)`
    - `dsl.order(dsl.order_by(fruit.price, dsl.Asc))`
- Fully supported equality + simple field order
  - File: `src/case_studies/hippo_schema.gleam`
  - Function: `query_hippos_by_gender`
  - Example:
    - `dsl.filter(exclude_if_missing(hippo.gender) == gender_to_match)`
    - `dsl.order(dsl.order_by(hippo.name, dsl.Desc))`

### Currently Supported Precisely

- `exclude_if_missing(entity.field) <. simple_param` + `order_by(entity.field, Asc)`
- `exclude_if_missing(entity.field) == simple_or_scalar_param` + `order_by(entity.field, Asc|Desc)`
- computed comparisons/orders such as `age(exclude_if_missing(...)) > min_age` + `order_by(age(...), Desc)`
- relationship access through `nullable(...).item.<field>` in expression parsing

### Effect of Strict Parsing

- Parsing fails fast for unsupported constructs.
- Codegen only emits concrete query SQL/functions for specs that match the SQL-emittable subset.
- Non-emittable but valid parsed specs remain represented in schema metadata without silent downgrade.

## Codegen Rules

- SQL/query function emission is driven from parsed `Query`:
  - `operator Eq` -> equality SQL
  - `operator Lt` -> less-than SQL
- Emission rules must be generic and schema-driven (no per-module branching).
- Only generatable query specs are emitted as concrete query functions.
- Non-generatable query specs are skipped by query codegen selection logic.

## Relationship Query Module Policy

- Keep generated API query functions in `src/case_studies/hippo_db/query.gleam`.
- `relationship_queries.gleam` is retired; schema-declared queries are generated into `hippo_db/query.gleam`.
- Do not force function-name collisions (`query_hippos_by_gender`) across modules.

## TODO List

- [x] Remove `spec.codegen` branching in parser/generator paths used by production code.
- [x] Add `MissingBehavior` to `Filter.BooleanFilter`.
- [x] Keep fruit and hippo generated query snapshots green.
- [x] Extend parser to infer `MissingBehavior.Nullable` from `nullable(...)`.
- [x] Add explicit representation for computed selections/filters (`age(...)`, nested relationship projections) instead of fallback.
- [x] Replace compatibility fallback with explicit support or explicit actionable failure.
- [x] Migrate/retire `relationship_queries.gleam` only when query-model supports its complex shapes.

Out of scope

- [ ] Enforce and test that no module-specific special-casing exists in query generation.
- [ ] Enforce and test that schema-declared queries never require consumer-authored custom SQL.

## Acceptance Criteria (Next Milestone)

- Parser can represent all current `fruit_schema` and `hippo_schema` query specs without fallback defaults.
- `Predicate(Compare(...))` includes correct `MissingBehavior` inference (`ExcludeIfMissing` vs `Nullable`).
- `hippo_db/query.gleam` contains all generated query functions intended by schema query specs.
- Test suite passes after removing compatibility fallback behavior.
- Query generator logic is fully generic (module-agnostic), with no hard-coded case-study rules.
- Consumers are never required to provide manual/custom SQL for schema-declared queries.

## Proposal: Tighten Without Losing Expressiveness

The current gaps are primarily modeling gaps (not fundamental inconsistency in the examples).  
To tighten safely, move from string/path-only pieces to a constrained query AST.

### 1) Extend Query Type to Expression-Based AST

Replace stringly filter/shape/order payloads with explicit expression nodes.

```gleam
pub type Query {
  Query(shape: Shape, filter: Option(Filter), order: Order)
}

pub type Shape {
  NoneOrBase
  Subset(items: List(ShapeItem))
}

pub type ShapeItem {
  ShapeField(alias: Option(String), expr: Expr)
}

// alias optional; auto-derive output name from expr when unambiguous
// explicit alias required only when derivation is ambiguous

pub type Filter {
  NoFilter
  Predicate(pred: Pred)
}

pub type Pred {
  Compare(left: Expr, operator: Operator, right: Expr, missing_behavior: MissingBehavior)
  And(items: List(Pred))
  Or(items: List(Pred))
  Not(item: Pred)
}

pub type Order {
  UpdatedAtDesc
  CustomOrder(expr: Expr, direction: dsl.Direction)
}

pub type Expr {
  Field(path: List(String))
  Param(name: String)
  Call(func: ExprFn, args: List(Expr))
}

pub type ExprFn {
  ExcludeIfMissingFn
  NullableFn
  AgeFn
}
```

### 2) What This Unlocks

- Computed shape entries (for example `#("age", age(...))`)
- Relationship-based shape expressions (`nullable(...).item.email`)
- Computed filters (`age(...) > min_age`)
- Computed order expressions (`order_by(age(...), Desc)`)
- Future nested boolean filters without custom SQL escape hatches

### 3) Tightness Rules (Still Strict)

- Parser only allows whitelisted functions represented in `ExprFn`.
- Field paths must resolve against schema entities/relationships.
- `Param(name)` must refer to declared query parameters.
- Unknown functions/paths/operators are explicit parser errors.
- No module-specific exceptions or codegen branching by schema filename.

### 4) Migration Plan

1. Introduce AST types in `schema_definition`.
2. Keep current supported simple patterns, but map them into AST (`Field`/`Param`/`Call`).
3. Add AST parsing for current hippo complex query patterns (`age`, `nullable`, computed shape items).
4. Update codegen to consume AST only.
5. Remove compatibility fallback once all existing case-study queries parse and generate directly from AST.

### 5) Success Criteria for This Proposal

- Existing `fruit_schema` and `hippo_schema` queries parse into AST without fallback defaults.
- Generated SQL for all schema-declared queries is AST-driven and module-agnostic.
- Unsupported constructs fail with actionable parse/codegen diagnostics (not manual SQL requirements).
