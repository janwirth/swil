# Custom Scalar JSON Storage Spec

## Goal

Support non-enum `*Scalar` types in generated API code so they can be:

- stored in SQLite `TEXT` columns
- encoded to JSON on write
- decoded from JSON on read
- used in entity fields like `option.Option(ViewConfigScalar)`

## Scope

- API code generation for row decode + upsert/update/query bind expressions.
- Schema validation updates that currently reject non-enum scalars.
- A dedicated generator module and tests for scalar encode/decode helpers.

## Non-goals

- Changes to DSL query shape semantics.
- New SQL storage types beyond `TEXT`.
- Runtime migrations of existing non-JSON text values.

## Current Problem

`library_manager_schema.gleam` includes:

- `view_config: option.Option(ViewConfigScalar)`

Current generator behavior rejects this with:

- `Unsupported field type in Tab.view_config: Option(ViewConfigScalar). Non-enum scalar decoding is not implemented yet.`

## Required Behavior

### 1) Support Optional Custom Scalars in Entity Fields

- `Option(CustomScalar)` must pass schema validation.
- Generated row decoders must decode DB text into `Option(CustomScalar)`.
- Generated upsert/update/query binds must encode `Option(CustomScalar)` to DB text.

### 2) DB Representation

- Column type remains `TEXT`.
- `None` encodes as JSON `null` text (`"null"`).
- `Some(value)` encodes to JSON text.

### 3) Generated Helper Functions

For each used scalar type, generate:

- `<scalar>_to_db_string(Option(Scalar)) -> String`
- `<scalar>_from_db_string(String) -> Option(Scalar)`

Behavior:

- Enum-only scalars keep current pattern-match string mapping.
- Non-enum scalars use JSON encode/decode.
- Invalid/unknown DB payload must fail explicitly during read decode.

### 4) Wiring

- Remove non-enum scalar rejection in:
  - schema strict validation
  - API decoder generation assert path
- Ensure row/upsert/update/query/facade all reference generated scalar helpers for both enum and non-enum scalars.
- Keep helper naming stable (existing `scalar_type_snake_case` conventions).

## Proposed Implementation

### A) New Module

Create a new generator module under `src/generators/api/` focused on scalar codecs:

- enum scalar codec generation (migrate existing helper generation there)
- non-enum scalar JSON codec generation
- shared function chunk builders consumed by row/api generation modules

### B) Validation Changes

- Update schema module builder validation to allow `Option(non-enum scalar)`.
- Update API decoder type assertion to no longer panic for non-enum scalar option fields.

### C) Decoder/Encoder Changes

- In row decoder generation:
  - decode DB field as string
  - pass through `<scalar>_from_db_string`
- In upsert/update/query binding generation:
  - call `<scalar>_to_db_string` for scalar values
  - wrap in `sqlight.text(...)`

### D) Tests

Create dedicated tests for scalar codecs (self-contained Gleam types):

- enum scalar roundtrip
- record scalar roundtrip
- malformed JSON decode fails explicitly
- non-JSON legacy text (including empty string) fails explicitly

Add/adjust integration coverage so:

- `library_manager_schema.gleam` parsing/generation no longer fails on `ViewConfigScalar`
- existing enum scalar case (e.g. hippo) remains green

## Acceptance Criteria

- `Option(ViewConfigScalar)` compiles through schema parse + API generation.
- Generated DB read/write path for non-enum scalars uses scalar helper functions.
- Enum scalar behavior remains unchanged.
- New dedicated scalar codec tests pass.
- Existing relevant tests continue passing.

## Open Questions (Need Decision)

## Decisions

1. **No backwards compatibility in this phase**
   - Legacy non-JSON values are not supported and must fail decode explicitly.

2. **Decode failure policy**
   - Malformed JSON or schema mismatch fails explicitly during read decode.

3. **Helper visibility**
   - Scalar codec helpers are internal to generated row module.
   - API continues exposing scalar types and constructors as schema surface.

4. **Scope**
   - Implement support for `Option(CustomScalar)` in entities.
   - Entity fields are optional in this phase.

5. **`None` representation**
   - Encode `None` as JSON `null` text.
