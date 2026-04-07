# Custom query shapes (`dsl.shape`)

**Spec only.** Defines how `dsl.shape(..)` describes the **logical projection** of a `query_*` pipeline: which fields appear in the result type and, once wired through generators, which columns appear in `select` and how rows are decoded.

Today the schema **parser** builds `schema_definition.Shape` (`NoneOrBase` vs `Subset`) from source; **SQL / API codegen** still largely behaves as if every list query returns the full root entity plus `dsl.MagicFields`. This file is the contract for closing that gap.

## Terminology

| Source level | Meaning |
| ------------ | ------- |
| **Shape** | The single argument to `dsl.shape(..)` after `dsl.query(root)`. |
| **Shape spec** | One element of a tuple shape, or the whole non-tuple shape (`root` / `None` / entity variable). |

## Shape forms

1. **Full entity (no custom projection)**  
   - `dsl.shape(root_entity_var)` where the variable is the **first** `query_*` parameter (same name as the entity binding).  
   - Or `dsl.shape(None)` where the parser treats `None` as "no projection" / base row.  
   - **IR:** `Shape.NoneOrBase`.

2. **Custom projection (tuple)**  
   - `dsl.shape(#( spec1, spec2, ... ))`  
   - The **outer** `#(...)` is the shape: a fixed-order list of columns/derived values in the result.  
   - **IR:** `Shape.Subset(selection: List(ShapeItem))`.

### Shape spec elements (inside the outer tuple)

Each element is either:

- **Explicit name:** `#("column_alias", expr)`  
  - The string is the **result key** / logical column alias (e.g. `"owner_email"`).  
  - `expr` uses the same expression subset as filters/order (`Field`, `Param`, `exclude_if_missing`, `nullable`, `age`, dotted paths, etc.).

- **Auto-derived name:** `expr` without a wrapping pair tuple  
  - The parser assigns `ShapeField.alias` when it can infer a stable name, e.g.  
    - last segment of a simple field path (`hippo.name` → `"name"`),  
    - `age(...)` → `"age"`,  
    - `magic.id` / `_magic_fields.id` → `"id"` (second parameter name appears in the internal path; the **alias** is still `"id"`).  
  - If inference fails, the parser reports that an explicit `#("alias", expr)` is required.

**Order:** `Subset.selection` preserves source tuple order.

## Semantics (target)

- A `Subset` query returns a **named record per row** — not a tuple and not the full entity type.
- **Output type naming:** for a query function `query_foo_bar`, the generated output type is `QueryFooBarOutput` (PascalCase of the function name + `Output`), emitted as a `pub type` in the `row` module.
- **Output type fields:** one labelled field per shape alias, in declaration order.
- **SQL:** `select` must list only the expressions needed for the shape (plus anything the runtime absolutely requires for decoding, if any — document when added).
- **Types:** fields in `QueryFooBarOutput` mirror the inferred Gleam type of each `expr` (e.g. `Int` for `age(...)`, `option.Option(String)` for `nullable(...).field`).
- **Decoder:** the `row` module emits a `query_foo_bar_output_decoder()` function that decodes a single row into `QueryFooBarOutput`.
- **Filters / order:** unchanged; they may reference paths not present in the shape (the shape only restricts the **returned** projection).

### Output type naming

| Query fn name | Generated output type |
| --- | --- |
| `query_old_hippos_owner_emails` | `QueryOldHipposOwnerEmailsOutput` |
| `query_row_ids` | `QueryRowIdsOutput` |

Rule: strip leading `query_` if present, convert `snake_case` to `PascalCase`, append `Output`.

## Examples

Full entity (current default for many case studies):

```gleam
dsl.query(hippo)
|> dsl.shape(hippo)
|> dsl.filter_bool(...)
|> dsl.order_by(hippo.name, dsl.Desc)
```

Custom projection — explicit and auto-derived aliases in one tuple.  
For `query_old_hippos_owner_emails`, the generator emits in the `row` module:

```gleam
pub type QueryOldHipposOwnerEmailsOutput {
  QueryOldHipposOwnerEmailsOutput(age: Int, owner_email: option.Option(String))
}

pub fn query_old_hippos_owner_emails_output_decoder() {
  use age <- decode.field(0, decode.int)
  use owner_email <- decode.field(1, decode.optional(decode.string))
  decode.success(QueryOldHipposOwnerEmailsOutput(age:, owner_email:))
}
```

And the `query` module emits:

```gleam
pub fn query_old_hippos_owner_emails(
  conn: sqlight.Connection,
  min_age min_age: Int,
) -> Result(List(row.QueryOldHipposOwnerEmailsOutput), sqlight.Error) {
  sqlight.query(
    old_hippos_owner_emails_sql,
    on: conn,
    with: [sqlight.int(min_age)],
    expecting: row.query_old_hippos_owner_emails_output_decoder(),
  )
}
```

Id-only rows (second parameter must be `dsl.MagicFields`; alias derived as `"id"`):

```gleam
pub fn query_row_ids(row: Row, magic: dsl.MagicFields, _unused: Int) {
  dsl.query(row)
  |> dsl.shape(#(magic.id))
  |> dsl.filter_bool(option.None)
  |> dsl.order_by(option.None, dsl.Desc)
}
```

Generates `QueryRowIdsOutput(id: Int)`.

## Modules

### `row` module

For each `Subset` query spec, the `row` module gains:

1. A `pub type QueryFooBarOutput { QueryFooBarOutput(field1: T1, field2: T2, ...) }`.
2. A `pub fn query_foo_bar_output_decoder() -> decode.Decoder(QueryFooBarOutput)`.

### `query` module

For each `Subset` query spec:

- SQL constant selects only the shape expressions.
- Function return type is `Result(List(row.QueryFooBarOutput), sqlight.Error)`.
- `expecting:` calls `row.query_foo_bar_output_decoder()`.

### `api` facade module

Forwards with the same `row.QueryFooBarOutput` return type.

## Parser (`schema_definition/query`)

- `parse_shape_expr` / `parse_shape_item` / `derive_shape_alias` implement the rules above.  
- Pipeline extraction must continue to supply the `shape(..)` argument whether the body uses `|>` or nested calls (see existing query pipeline peelers).

## Tests (minimum)

| Layer | What |
| ----- | ---- |
| **Parser / IR** | `Subset` preserves aliases and expression AST; `NoneOrBase` for `shape(entity)`; id-only `shape(#(magic.id))` → single field alias `"id"`. |
| **Structural** | Generated `row` module contains `QueryOldHipposOwnerEmailsOutput` type and decoder; generated SQL selects only the projection columns. |
| **E2E** | Runtime query returns only the shaped fields accessible by label (e.g. `.age` and `.owner_email`). |

## Non-goals (v1)

- Arbitrary Gleam expressions inside shape (only the supported DSL expression AST).  
- Renaming or reordering shape fields at the SQL layer without matching IR aliases.

---

## Implementation todo

- [x] **Spec** — this file.  
- [x] **Parser IR** — `Shape` / `ShapeItem` + tests (`test/schema_definition/custom_shape_parse_test.gleam`).  
- [ ] **Output types + decoders in `row`** — emit `QueryFooBarOutput` type and `query_foo_bar_output_decoder()` for each `Subset` spec.  
- [ ] **SQL + `query` module** — `Subset` drives `select` list; function uses `row.query_foo_bar_output_decoder()` and returns `List(row.QueryFooBarOutput)`.  
- [ ] **Facade** — forward with correct `row.QueryFooBarOutput` return type.  
- [ ] **Case studies** — regen `hippo_db` snapshots.
