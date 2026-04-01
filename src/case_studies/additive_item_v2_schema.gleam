import gleam/option

/// Snapshot v2: adds `height`, and a second identity **`ByName`** (name-only upsert path).
///
/// `ByName` is listed **first** so generated pragma migration uses `item_by_name` as the canonical
/// unique index; `ByNameAndAge` stays available for API upserts (same pattern as `ImportedTrack`
/// with `ByTitleAndArtist` + `ByFilePath`, but only the first variant’s index is reconciled).
pub type Item {
  Item(
    name: option.Option(String),
    age: option.Option(Int),
    height: option.Option(Float),
    identities: ItemIdentities,
  )
}

pub type ItemIdentities {
  ByName(name: String)
  ByNameAndAge(name: String, age: Int)
}
