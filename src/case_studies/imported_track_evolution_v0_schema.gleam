import gleam/option

/// Oldest snapshot: no `external_source_url`, no `added_to_library_at`.
/// Pair with `imported_track_evolution_v1_schema` / `v2_schema` for migration tests.
pub type ImportedTrack {
  ImportedTrack(
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    identities: ImportedTrackIdentities,
  )
}

pub type ImportedTrackIdentities {
  ByServiceAndSourceId(service: String, source_id: String)
}
