# Row-Derived Types + Connection-Wrapped Cardinality

## Goal

Generated `*_db/row.gleam` decoders must decode into a **row-local type derived from schema entities**, not the schema entity type itself.

## Row Type Contract

For each schema entity `E`:

- Generate a row-local type in `*_db/row.gleam` (example: `ImportedTrackRow`).
- Include all scalar/data fields from `E`.
- Exclude `identities`.
- If `E` has `relationships: ERelationships`, flatten relationship fields into the row-local type as top-level fields.
- Preserve relationship field types (subject to the connection shape rule below).

## Connection Shape Rule

Inside `*Relationships` containers:

- `BelongsTo` and `Mutual` are the top-level connection types.
- Cardinality/nullability is encoded in their first type parameter (`List(T)` or `option.Option(T)`).
- Outer wrapping like `option.Option(BelongsTo(...))` / `option.Option(Mutual(...))` is invalid.

Examples:

- Invalid: `option.Option(BelongsTo(TrackBucket, Nil))`
- Invalid: `option.Option(Mutual(Hippo, FriendshipAttributes))`
- Invalid: `dsl.BelongsTo(TrackBucket, Nil)`
- Valid: `dsl.BelongsTo(option.Option(TrackBucket), Nil)`
- Valid: `dsl.BelongsTo(List(Tag), AppliedTagRelationshipAttributes)`
- Valid: `dsl.Mutual(option.Option(Hippo), FriendshipAttributes)`
- Valid: `dsl.Mutual(List(Hippo), FriendshipAttributes)`

## Enforcement

### Schema-level parser enforcement

- Validate `*Relationships` field types.
- Reject invalid `BelongsTo` / `Mutual` shapes with a parse error.

### Row codegen enforcement

- Build row-local generated type from entity data fields plus flattened relationships.
- Decode DB rows into that row-local type.
- Use flattened defaults that match the connection cardinality:
  - `BelongsTo(List(_), _)` / `Mutual(List(_), _)` -> `[]`
  - `BelongsTo(option.Option(_), _)` / `Mutual(option.Option(_), _)` -> `option.None`

## Expected Generated Type Example

For `ImportedTrack` in `tuna_schema`:

```gleam
pub type ImportedTrackRow {
  ImportedTrackRow(
    from_source_root: option.Option(String),
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),

    // flattened from ImportedTrackRelationships
    tags: List(#(tuna_schema.Tag, tuna_schema.AppliedTagRelationshipAttributes)),
    // if no attributes no tuple, just plain value
    track_bucket: option.Option(tuna_schema.TrackBucket),
  )
}
```

Decoder signature:

```gleam
pub fn importedtrack_with_magic_row_decoder() -> decode.Decoder(
  #(ImportedTrackRow, dsl.MagicFields),
)
```

## Regeneration / Compile Expectations

- Update schema usage to optional/list `BelongsTo` first arg where needed.
- Regenerate `tuna_db`.
- Compilation succeeds with `row.gleam` independent from schema entity constructor shape (`identities` and nested `relationships`).
