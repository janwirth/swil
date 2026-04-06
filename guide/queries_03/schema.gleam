//// Guide 03 — queries (schema)
////
//// Any `pub fn query_* (entity, dsl.MagicFields, ...)` becomes a typed query in `schema_db/query.gleam`.
//// Generate: `gleam run -- src/guide/queries_03/schema.gleam`

import gleam/option
import gleam/string
import swil/dsl

pub type Guide03Note {
  Guide03Note(
    title: option.Option(String),
    body: option.Option(String),
    identities: Guide03NoteIdentities,
  )
}

pub type Guide03NoteIdentities {
  ByTitle(title: String)
}

/// Rows whose title starts with `prefix` (empty `title` option excluded by filter).
pub fn query_guide03_notes_by_title_prefix(
  note: Guide03Note,
  _magic_fields: dsl.MagicFields,
  prefix: String,
) {
  dsl.query(note)
  |> dsl.shape(note)
  |> dsl.filter_bool(case note.title {
    option.Some(t) -> string.starts_with(t, prefix)
    option.None -> False
  })
  |> dsl.order(note.title, dsl.Asc)
}
