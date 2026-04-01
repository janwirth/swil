//// Guide 01 — foundations (schema)
////
//// From repo root:
////   gleam run -- src/guide/foundations_01/schema.gleam
//// Emits `schema_db/` next to this file.
////
//// Identity columns must also appear as normal fields (here `name` + `ByName(name)`).
//// Magic columns are not declared on the type; APIs return `#(Guide01Item, dsl.MagicFields)`.

import gleam/option

pub type Guide01Item {
  Guide01Item(
    name: option.Option(String),
    note: option.Option(String),
    identities: Guide01ItemIdentities,
  )
}

pub type Guide01ItemIdentities {
  ByName(name: String)
}
