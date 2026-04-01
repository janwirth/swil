import gleam/option
import gleam/time/timestamp.{type Timestamp}

/// Reference snapshot **v2**: adds `added_to_library_at` (not in v1).
pub type ImportedTrack {
  ImportedTrack(
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
    identities: ImportedTrackIdentities,
  )
}

pub type ImportedTrackIdentities {
  ByServiceAndSourceId(service: String, source_id: String)
}
