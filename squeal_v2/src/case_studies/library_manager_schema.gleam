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
    tags: List(BelongsTo(Tag, TrackBucketRelationshipAttributes))
  )
}

pub type TrackBucketRelationshipAttributes {
  TrackBucketRelationshipAttributes(
    value: option.Option(Int),
  )
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

// I haven't figured out tags yet

pub type TabIdentities {
  ByTabLabel(label: String)
}

/// Join naming for [`dsl.boolean_filter_tag_join_sql`](dsl.boolean_filter_tag_join_sql) on `trackbucket_tag`.

pub fn query_tabs_for_tab_bar(tab: Tab, tab_meta: dsl.MagicFields, _limit: Int) {
  dsl.query(tab)
  |> dsl.shape(option.None)
  |> dsl.filter(option.None)
  |> dsl.order(dsl.order_by(tab_meta.updated_at, dsl.Desc))
}

pub fn query_tracks_by_view_config(track_bucket: TrackBucket, magic_fields: dsl.MagicFields, filter_config: FilterConfigScalar) {
  dsl.query(track_bucket)
  |> dsl.shape(option.None)
  |> dsl.filter(filter_track_bucket_by_tag(track_bucket, filter_config))
  |> dsl.order(dsl.order_by(dsl.MagicFields, dsl.Desc))  
}

// scalar is a single value, like a string, a number, a boolean, etc, not another object type in the db
// custom scalars could also be vectors
// scalars have their own implementaiton - to / from sql I guess

// AND [OR[], AND[]]
// 
import gleam/list

pub fn any(relationship: List(BelongsTo(related, attribs)), select: fn(related, dsl.MagicFields, attribs) -> Bool)
  -> dsl.BooleanFilter(BelongsTo(related, attribs)) {
  panic("this is DSL")
}

pub type FilterConfigScalar  = RecursiveFilterSpec(TagExpressionScalar)

// this doesn't even need to be here - it can be a shared function, no generation
// execution is offloaded to engine
pub fn filter_track_bucket_by_tag(
  track_bucket: TrackBucket,
  filter: RecursiveFilterSpec(TagExpressionScalar),
) -> dsl.BooleanFilter(BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
  case filter {
    And(items: items) ->
      dsl.And(
        exprs: list.map(items, fn(item) { filter_track_bucket_by_tag(track_bucket, item) }),
      )
    Or(items: items) ->
      dsl.Or(
        exprs: list.map(items, fn(item) { filter_track_bucket_by_tag(track_bucket, item) }),
      )
    Not(item: item) -> dsl.Not(expr: filter_track_bucket_by_tag(track_bucket, item))
    Terminal(item: tag_expression) ->
    // on any tag that is connected and matches
      case tag_expression {

        Has(tag_id: tag_id) ->
          any(track_bucket.relationships.tags, fn(tag, magic_fields, edge_attribs) {
            magic_fields.id == tag_id
          })
        IsAtLeast(tag_id: tag_id, value: value) ->
          any(track_bucket.relationships.tags, fn(tag, magic_fields, edge_attribs) {
            dsl.exclude_if_missing(edge_attribs.value) >= value
          })
        IsAtMost(tag_id: tag_id, value: value) ->
          any(track_bucket.relationships.tags, fn(tag, magic_fields, edge_attribs) {
            dsl.exclude_if_missing(edge_attribs.value) <= value
          })
        IsEqualTo(tag_id: tag_id, value: value) ->
          any(track_bucket.relationships.tags, fn(tag, magic_fields, edge_attribs) {
            dsl.exclude_if_missing(edge_attribs.value) == value
          })

      }
  }
}
pub fn terminal(track_bucket: TrackBucket, tag_expression: TagExpressionScalar) -> dsl.BooleanFilter(BelongsTo(Tag, TrackBucketRelationshipAttributes)) {
    // Terminal(item: tag_expression) ->
    // on any tag that is connected and matches
      case tag_expression {

        Has(tag_id: tag_id) ->
          any(track_bucket.relationships.tags, fn(tag, magic_fields, edge_attribs) {
            magic_fields.id == tag_id
          })
        IsAtLeast(tag_id: tag_id, value: value) ->
          any(track_bucket.relationships.tags, fn(tag, magic_fields, edge_attribs) {
            dsl.exclude_if_missing(edge_attribs.value) >= value
          })
        IsAtMost(tag_id: tag_id, value: value) ->
          any(track_bucket.relationships.tags, fn(tag, magic_fields, edge_attribs) {
            dsl.exclude_if_missing(edge_attribs.value) <= value
          })
        IsEqualTo(tag_id: tag_id, value: value) ->
          any(track_bucket.relationships.tags, fn(tag, magic_fields, edge_attribs) {
            dsl.exclude_if_missing(edge_attribs.value) == value
          })

      }
}



pub type RecursiveFilterSpec(terminal) {
  And(items: List(RecursiveFilterSpec(terminal)))
  Or(items: List(RecursiveFilterSpec(terminal)))
  Not(item: RecursiveFilterSpec(terminal))
  Terminal(item: terminal)
}

pub type TagExpressionScalar {
  Has(tag_id: Int)
  IsAtLeast(tag_id: Int, value: Int)
  IsAtMost(tag_id: Int, value: Int)
  IsEqualTo(tag_id: Int, value: Int)
}

