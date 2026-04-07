# Query output types (per-query rows)

**Problem.** Schema entity types use `dsl.BelongsTo(a, attrs)` (and `option.Option(BelongsTo(...))`, `List(BelongsTo(...))`, etc.) as **DSL markers** for joins, filters, and documentation. Row decoders and runtime values are **not** those constructors: they use plain data (`List` of related rows, optional edge fields, etc.). Reusing the schema’s `*Relationships` record in generated `query_*` return types therefore causes type errors (e.g. assigning `option.None` where a `BelongsTo` is expected).

**Rule.** Every `query_*` (and any generated row decoder pairing) gets a **generated output type** for that query’s root row. Do not embed the user-authored schema relationship fields verbatim in that type. This aligns with [CUSTOM_SHAPE_SPEC.md](./CUSTOM_SHAPE_SPEC.md): the return type is the **projection** for that pipeline, not necessarily the schema’s entity type.

## Lowering `BelongsTo` in generated output types

When the logical result includes a relationship edge that is expressed in the schema as `BelongsTo(Related, EdgeAttrs)`:

| Edge attributes in schema | Generated field type (many side / collected) |
| ------------------------- | -------------------------------------------- |
| `Nil` or no meaningful edge row | `List(Related)` |
| Non-`Nil` edge attribute type `EdgeAttrs` | `List(#(Related, EdgeAttrs))` |

For optional singular edges (`option.Option(BelongsTo(Related, EdgeAttrs))`), the same lowering applies inside `Option`: `option.Option(Related)` vs `option.Option(#(Related, EdgeAttrs))` as appropriate.

For schema fields already written as `List(BelongsTo(Related, EdgeAttrs))`, the generated type is still `List(#(Related, EdgeAttrs))` or `List(Related)` per the table — the `List` is the runtime shape; `BelongsTo` is stripped in the output type.

**Naming.** Use stable generated names (e.g. `ImportedTrackQueryRow`, or names derived from query function + module) so schema refactors do not silently change unrelated APIs.

## Decoder contract

The row decoder for a query must construct the **same** generated type: no `BelongsTo(...)` or `option.None` standing in for an unloaded `BelongsTo`. If a relationship is not loaded in a given query, omit it from that query’s generated shape or use an explicit `option.Option` / empty `List` of the lowered type — never the DSL relationship constructor.

## Non-goals (v1)

- Exposing schema `ImportedTrack` unchanged as the list row type when joins are absent or partial.
- Requiring hand-written row types to mimic `dsl` phantom types at runtime.
