import gleam/option

/// Snapshot v1: natural key is **name + age** (`ByNameAndAge`). Pair with `additive_item_v2_schema`.
pub type Item {
  Item(
    name: option.Option(String),
    age: option.Option(Int),
    identities: ItemIdentities,
  )
}

pub type ItemIdentities {
  ByNameAndAge(name: String, age: Int)
}
