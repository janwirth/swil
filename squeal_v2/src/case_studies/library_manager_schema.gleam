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
    tags: List(dsl.BelongsTo(Tag, TrackBucketRelationshipAttributes))
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
  |> dsl.order(dsl.order_by(tab_meta.updated_at, dsl.Desc))
}

// pub fn query_tracks_by_view_config(track_bucket: TrackBucket, view_config: ViewConfigScalar) {
//   dsl.query(track_bucket)
//   |> dsl.shape(option.None)
//   |> dsl.filter(option.None)
//   |> dsl.order(dsl.order_by(view_config.updated_at, dsl.Desc))
// }

// scalar is a single value, like a string, a number, a boolean, etc, not another object type in the db
// custom scalars could also be vectors
// scalars have their own implementaiton - to / from sql I guess

// AND [OR[], AND[]]
// 
import gleam/list


pub type FilterScalar {
  And(exprs: List(FilterScalar))
  Or(exprs: List(FilterScalar))
  Not(expr: FilterScalar)
  TagExpression(tag_id: Int, operator: TagExpressionScalar)
}

pub type TagExpressionScalar {
  Has
  DoesNotHave
  IsAtLeast(value: Int)
  IsAtMost(value: Int)
  IsEqualTo(value: Int)
}
