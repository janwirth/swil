# Runtime Extraction Spec

Analysis of the generated `*_db` case studies to identify code that can be moved into
`swil/runtime/` — reducing the volume and complexity of what the code generator must emit
and what must be covered by tests.

---

## Current state

`swil/runtime/` already provides two well-targeted modules:

| Module | Purpose |
|---|---|
| `api_help` | Sentinel-based Option↔SQLite encoding, magic field construction, date/timestamp helpers |
| `cmd_runner` | Batched command executor — `run_cmds`, `group_by_variant`, `exec_batch` |

Generated `*_db` modules are: `cmd.gleam`, `row.gleam`, `get.gleam`, `query.gleam`,
`migration.gleam`, `api.gleam`.

---

## Identified duplication

### 1. Migration boilerplate (highest impact)

Every `migration.gleam` contains ~300 lines of near-identical helpers that only vary by
table name, column list, and index names. The repetitive helpers are:

```
pragma_index_name_origin_rows/2   — identical across all migrations
type_matches/2                    — identical
first_surplus_column/2            — identical logic, only local Col type differs
first_mismatched_column_name/2    — identical logic, only local Col type differs
first_missing_column/2            — identical logic, only local Col type differs
alter_add_*_column_sql/1          — identical logic, parameterised by table name
apply_one_*_column_fix/2          — identical structure
reconcile_*_columns_loop/2        — identical structure
ensure_*_table/1                  — identical structure
drop_surplus_user_indexes_on_*/1  — identical structure
ensure_*_indexes/1                — identical structure (index names vary)
```

Each file also declares a private `type XxxCol { XxxCol(name, type_, notnull, pk) }` that
is structurally identical across every entity.

**Proposed extraction → `runtime/migration.gleam`**

Define a shared column spec type and a single entry-point that accepts the entity-specific
declarative data:

```gleam
/// Shared column descriptor — replaces the per-entity `XxxCol` private type.
pub type ColumnSpec {
  ColumnSpec(name: String, type_: String, notnull: Int, pk: Int)
}

/// All the entity-specific data a migration needs to supply.
pub type TableSpec {
  TableSpec(
    table: String,
    columns: List(ColumnSpec),
    create_table_sql: String,
    /// List of #(index_name, create_index_sql) pairs, in desired order.
    indexes: List(#(String, String)),
    /// TSV snapshot strings used for the final assert.
    expected_table_info: String,
    expected_index_list: String,
    /// #(index_name, expected_info_tsv) for each index.
    expected_index_infos: List(#(String, String)),
  )
}

/// Drop every table except those in `keep`, then reconcile `spec`.
pub fn run(
  conn: sqlight.Connection,
  keep: List(String),
  spec: TableSpec,
) -> Result(Nil, sqlight.Error)
```

Generated `migration.gleam` shrinks to: SQL constants + `ColumnSpec` list + one `run` call
(~50 lines instead of ~300). The 250-line helpers live in the runtime and are tested once.

---

### 2. Patch command builder (medium impact)

Every `PatchByIdentity` and `PatchById` branch in `cmd.gleam` repeats this accumulator
pattern verbatim for each patchable field:

```gleam
let #(set_parts, binds) = #([], [])
let #(set_parts, binds) = case field {
  option.None -> #(set_parts, binds)
  option.Some(v) -> #(["\"col\" = ?", ..set_parts], [sqlight.type(v), ..binds])
}
// ... repeat per field ...
let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [sqlight.int(now), ..binds])
let set_sql = string.join(list.reverse(set_parts), ", ")
let sql = "update \"table\" set " <> set_sql <> " where ... and \"deleted_at\" is null;"
let binds = list.flatten([list.reverse(binds), [<where binds>]])
#(sql, binds)
```

A 3-field entity generates ~25 lines per patch variant; a 6-field entity ~40 lines.

**Proposed extraction → `runtime/patch.gleam`**

```gleam
pub opaque type PatchBuilder

pub fn new() -> PatchBuilder

/// Each `add_*` only appends when the option is Some.
pub fn add_text(b: PatchBuilder, col: String, val: option.Option(String)) -> PatchBuilder
pub fn add_float(b: PatchBuilder, col: String, val: option.Option(Float)) -> PatchBuilder
pub fn add_int(b: PatchBuilder, col: String, val: option.Option(Int)) -> PatchBuilder
pub fn add_date(b: PatchBuilder, col: String, val: option.Option(calendar.Date)) -> PatchBuilder

/// For custom scalars already encoded to a sentinel string by the caller.
pub fn add_encoded_text(b: PatchBuilder, col: String, val: option.Option(String)) -> PatchBuilder

/// Always-present column (e.g. `updated_at = ?`); unconditionally appended.
pub fn add_always_int(b: PatchBuilder, col: String, val: Int) -> PatchBuilder

/// Assemble the final UPDATE statement.
/// `where_clause` is the fragment after `WHERE`, e.g. `"\"name\" = ? and \"deleted_at\" is null;"`.
/// `where_binds` are the values for that clause.
pub fn build(
  b: PatchBuilder,
  table: String,
  where_clause: String,
  where_binds: List(sqlight.Value),
) -> #(String, List(sqlight.Value))
```

Generated patch branches become a flat chain of `add_*` calls followed by `build`.

---

### 3. Single-row query helper (low impact, high clarity)

Every function in `get.gleam` is structurally identical:

```gleam
use rows <- result.try(sqlight.query(sql, on: conn, with: binds, expecting: decoder))
case rows {
  [] -> Ok(option.None)
  [r, ..] -> Ok(option.Some(r))
}
```

**Proposed addition → `runtime/query.gleam`** (new module)

```gleam
/// Execute `sql` and return the first matching row, or None if the result set is empty.
pub fn one(
  conn: sqlight.Connection,
  sql: String,
  binds: List(sqlight.Value),
  decoder: decode.Decoder(a),
) -> Result(option.Option(a), sqlight.Error)

/// Execute `sql` and return all matching rows.
/// Thin wrapper kept here so generated code has a uniform import pattern.
pub fn many(
  conn: sqlight.Connection,
  sql: String,
  binds: List(sqlight.Value),
  decoder: decode.Decoder(a),
) -> Result(List(a), sqlight.Error)
```

`query_one` eliminates 4–5 lines per lookup function; `query_many` is optional and mostly
for import uniformity (it's a pass-through to `sqlight.query`).

---

## What NOT to extract

| Area | Reason to keep generated |
|---|---|
| `cmd.gleam` — command types | Entity-specific variants; Gleam has no generics over variant shapes |
| `cmd.gleam` — Upsert/Update/Delete bindings | Trivially small; entity-specific field/type order |
| `row.gleam` — decoders | Reference entity types, identity constructors, and relationship shapes — unavoidably specific |
| `row.gleam` — scalar converters | Need entity-specific enum variants; pattern is trivial |
| `api.gleam` | Delegation layer is already 1-line-per-function; no logic to share |
| `query.gleam` — list/filter functions | SQL and param types vary; `query.many` wrapper is optional |

---

## Proposed new/modified runtime files

```
src/swil/runtime/
  api_help.gleam      (existing — no changes needed)
  cmd_runner.gleam    (existing — no changes needed)
  migration.gleam     (NEW) — ColumnSpec, TableSpec, run/3
  patch.gleam         (NEW) — PatchBuilder and add_*/build helpers
  query.gleam         (NEW) — one/4, many/4
```

---

## Estimated impact

| Module type | Lines before | Lines after | Saved per entity |
|---|---|---|---|
| `migration.gleam` | ~300 | ~55 | ~245 |
| `cmd.gleam` (patch branches only) | ~200 | ~140 | ~60 (2 patch variants × ~30) |
| `get.gleam` | ~50 | ~30 | ~20 |

With 10 entities in the current test suite, rough total saved: **(245 + 60 + 20) × 10 ≈ 3 250 lines**.

More importantly, the migration reconciliation engine and patch builder are currently
exercised implicitly through every case-study test run. Once moved to runtime, they can be
unit-tested directly and need not be re-exercised for each new entity.

---

## Open questions

1. **Multi-table migrations** (e.g. `hippo_db` has `human` + `hippo`): `migration.run`
   needs to handle a `List(TableSpec)` or accept a list of tables to `keep`. Design choice:
   accept `List(TableSpec)` and the `keep` list is derived from `spec.table` for each.

2. **`ensure_indexes` complexity**: some entities have zero indexes, some have multiple.
   The `TableSpec.indexes` field handles this uniformly, but the `expected_index_list` TSV
   snapshot format for zero-index tables needs verification.

3. **Patch builder for custom scalars**: `add_encoded_text` works if the caller encodes
   first (`row.gender_scalar_to_db_string(option.Some(v))`). This couples the call site to
   the encoding step but avoids adding scalar-type knowledge to the runtime builder.
   Alternative: accept a `fn(a) -> String` converter function in a generic `add_custom` variant.
