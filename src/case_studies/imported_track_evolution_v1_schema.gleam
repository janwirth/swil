import gleam/option

/// Reference snapshot **v1** (no `added_to_library_at`). Pair with
/// `imported_track_evolution_v2_schema` for migration tests.
pub type ImportedTrack {
  ImportedTrack(
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    external_source_url: option.Option(String),
    identities: ImportedTrackIdentities,
  )
}

pub type ImportedTrackIdentities {
  ByServiceAndSourceId(service: String, source_id: String)
}
