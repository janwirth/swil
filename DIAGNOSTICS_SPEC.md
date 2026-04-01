# Schema diagnostics

This document describes how swil surfaces parse and shape errors for schema modules. Implementations should match this spec; regressions are caught by unit tests that assert on formatted output.

## Goals

- **Rust-style layout**: When an error concerns a whole `pub type … { … }` block, the primary underline spans the full custom type in the source (multiple lines when needed), not only the opening line.
- **Secondary spans**: When a constraint applies to the entity record variant (constructor), emit an additional single-line diagnostic that points at the constructor name (for example `MyTrack` in `MyTrack(`).
- **Actionable text**: Messages that reject a shape include a **concrete Gleam example** of a valid fix (minimal entity + matching `*Identities` type), not only abstract hints.

## Primary vs related spans

- **Primary** `UnsupportedSchema` span: the main location (typically `CustomType.location` from Glance, which covers the full type definition).
- **Related** spans: a list of `#(Span, message)` rendered after the primary block, each using the same gutter style as single-line diagnostics.

## Entity missing `identities`

When a public type is classified as an entity candidate (single variant named like the type) but the variant has no labelled `identities` field:

1. Primary diagnostic: multiline highlight of the entire `pub type Name { … }`.
2. Message body: explain the issue and include a full example using the actual type name (e.g. `MyTrack` / `MyTrackIdentities` / `ByName`).
3. Append `hint_public_type_suffixes_or_entity()` as today.
4. Related diagnostic: span covering **only the constructor name** (`MyTrack` in `MyTrack(`), with a short note to add `identities: NameIdentities` on that variant.

## Formatting implementation

- Single-line spans continue to use `glance_armstrong.format_source_diagnostic/3`.
- Multi-line spans use local logic in `schema_definition/parse_error` (line gutter + per-line carets for the intersection with the span), so behaviour is consistent without forking `glance_armstrong`.

## Tests

- Parser/schema tests that cover this case must assert that `format_parse_error(source, err)` contains the example snippet (entity + `Identities` type) and the `identities:` label, and that output contains the related constructor note (or stable substrings thereof).
