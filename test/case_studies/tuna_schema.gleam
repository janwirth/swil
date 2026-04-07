// import rememberthename

// import rememberthename.{type FetchTrackRow}
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import swil/dsl

// pub type Source {
//   Source(url: String, identities: SourceIdentities)
  

// }
// pub type SourceIdentities {
//   ByUrl(url: String)
// }

/// One track row returned by [`fetch_source`](#fetch_source).
pub type ImportedTrack {
  ImportedTrack(
    from_source_root: option.Option(String),
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    /// Stable page URL when the adapter could resolve one; `None` when unknown.
    external_source_url: option.Option(String),
    identities: ImportedTrackIdentities,
    relationships: ImportedTrackRelationships
  )
}
pub type ImportedTrackRelationships {
  ImportedTrackRelationships(
    tags: dsl.BelongsTo(List(Tag), TagRelationshipAttributes),
  )
}

pub type TagRelationshipAttributes {
  TagRelationshipAttributes(
    value: option.Option(Int),
  )
}


pub type ImportedTrackIdentities {
  ByServiceAndSourceId(
    from_source_root: String,
    service: String,
    source_id: String,
  )
}

pub type Tag {
  Tag(
    label: option.Option(String),
    identities: TagIdentities
  )
}

pub type TagIdentities {
  ByLabel(  
    label: String,
  )
}

pub fn query_track_by_source_root(track: ImportedTrack, magic: dsl.MagicFields, source_root: String) {
  dsl.query(track)
  |> dsl.shape(track)
  |> dsl.filter_bool(dsl.exclude_if_missing(track.from_source_root) == source_root)
  |> dsl.order_by(track.added_to_library_at, dsl.Desc)
}