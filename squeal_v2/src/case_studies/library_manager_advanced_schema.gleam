import dsl/dsl.{type BelongsTo}
import gleam/option

// id / created_at / updated_at / deleted_at come from `dsl.MagicFields`, not the schema type.
pub type ImportedTrack {
  ImportedTrack(
    title: option.Option(String),
    artist: option.Option(String),
    file_path: option.Option(String),
    tags: List(Tag),
    identities: ImportedTrackIdentities,
  )
}

pub type ImportedTrackIdentities {
  ByTitleAndArtist(title: String, artist: String)
  ByFilePath(file_path: String)
}

pub type Tag {
  Tag(
    label: option.Option(String),
    emoji: option.Option(String),
    identities: TagIdentities,
  )
}

pub type TagIdentities {
  ByTagLabel(label: String)
}

// should I think about types for this?
// without path nor XYZ is invalid?
// let's stay with this and validate later?

pub type TrackBucket {
  TrackBucket(
    title: option.Option(String),
    artist: option.Option(String),
    matched_tracks: List(ImportedTrack),
    /// `(tag_row_id, weight)`; `tag_row_id` matches [`FilterScalar`](FilterScalar) `TagExpression.tag_id`.
    identities: TrackBucketIdentities,
    relationships: TrackBucketRelationships,
  )
}

pub type TrackBucketRelationships {
  TrackBucketRelationships(
    tags: List(BelongsTo(Tag, TrackBucketRelationshipAttributes)),
  )
}

pub type TrackBucketRelationshipAttributes {
  TrackBucketRelationshipAttributes(value: option.Option(Int))
}

pub type TrackBucketIdentities {
  ByBucketTitleAndArtist(title: String, artist: String)
}

// persisted in db
pub type Tab {
  Tab(
    label: option.Option(String),
    order: option.Option(Float),
    view_config: option.Option(ViewConfigScalar),
    identities: TabIdentities,
    tracks: List(TrackBucket),
  )
}

pub type ViewConfigScalar {
  ViewConfigScalar(
    filter_config: option.Option(String),
    source_selector: option.Option(String),
  )
}

pub type TabIdentities {
  ByTabLabel(label: String)
}

pub fn query_tabs_for_tab_bar(tab: Tab, tab_meta: dsl.MagicFields, _limit: Int) {
  dsl.query(tab)
  |> dsl.shape(option.None)
  |> dsl.order(tab_meta.updated_at, dsl.Desc)
}

pub fn query_tracks_by_view_config(
  track_bucket: TrackBucket,
  magic_fields: dsl.MagicFields,
  complex_tag_filter_expression: FilterExpressionScalar,
) {
  dsl.query(track_bucket)
  |> dsl.shape(option.None)
  // |> dsl.filter_bool(dsl.exclude_if_missing(track_bucket.title) == "hi")
  |> dsl.filter_complex(
    complex_tag_filter_expression,
    predicate_complex_tags_filter,
  )
  |> dsl.order(dsl.MagicFields, dsl.Desc)
}

// encodable type
pub type FilterExpressionScalar =
  dsl.BooleanFilter(TagExpressionScalar)

pub fn predicate_complex_tags_filter(
  track_bucket: TrackBucket,
  tag_expression: TagExpressionScalar,
) -> dsl.BooleanFilter(BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
  case tag_expression {
    Has(tag_id: tag_id) ->
      dsl.any(
        track_bucket.relationships.tags,
        fn(tag, magic_fields, edge_attribs) { magic_fields.id == tag_id },
      )
    IsAtLeast(tag_id: tag_id, value: value) ->
      dsl.any(
        track_bucket.relationships.tags,
        fn(tag, magic_fields, edge_attribs) {
          magic_fields.id == tag_id
          && dsl.exclude_if_missing(edge_attribs.value) >= value
        },
      )
    IsAtMost(tag_id: tag_id, value: value) ->
      dsl.any(
        track_bucket.relationships.tags,
        fn(tag, magic_fields, edge_attribs) {
          magic_fields.id == tag_id
          && dsl.exclude_if_missing(edge_attribs.value) <= value
        },
      )
    IsEqualTo(tag_id: tag_id, value: value) ->
      dsl.any(
        track_bucket.relationships.tags,
        fn(tag, magic_fields, edge_attribs) {
          magic_fields.id == tag_id
          && dsl.exclude_if_missing(edge_attribs.value) == value
        },
      )
  }
}

pub type TagExpressionScalar {
  Has(tag_id: Int)
  IsAtLeast(tag_id: Int, value: Int)
  IsAtMost(tag_id: Int, value: Int)
  IsEqualTo(tag_id: Int, value: Int)
}
