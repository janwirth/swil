//// Guide 02 — built-in operations (schema)
////
//// Same ideas as lesson 01, plus an extra optional column (`sku`) to illustrate
//// additive migration: after lesson 01, you would add `sku` here, run
//// `gleam run -- src/guide/built_in_ops_02/schema.gleam`, then call `migrate(conn)`
//// again on an existing DB so the new column appears (nullable for old rows).
////
//// Generate: `gleam run -- src/guide/built_in_ops_02/schema.gleam`

import gleam/option

pub type Guide02Item {
  Guide02Item(
    name: option.Option(String),
    note: option.Option(String),
    sku: option.Option(String),
    identities: Guide02ItemIdentities,
  )
}

pub type Guide02ItemIdentities {
  ByName(name: String)
}
