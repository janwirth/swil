import case_studies/library_manager_advanced_schema.{
  type ImportedTrack, type Tab, type Tag, type TrackBucket,
}
import dsl/dsl
import gleam/option
import sqlight

/// Generated from `case_studies/library_manager_advanced_schema`.
///
/// Table of contents:
/// - `migrate/1`
/// - Entity ops: ImportedTrack, Tab, Tag, TrackBucket
/// - Query specs: `query_tabs_for_tab_bar`, `query_tracks_by_view_config`
pub fn migrate(_conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  panic as "TODO: generated migration SQL"
}

/// List up to 100 recently edited importedtrack rows.
pub fn last_100_edited_importedtrack(
  _conn: sqlight.Connection,
) -> Result(List(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Delete a importedtrack by the `ByTitleAndArtist` identity.
pub fn delete_importedtrack_by_title_and_artist(
  _conn: sqlight.Connection,
  _title: String,
  _artist: String,
) -> Result(Nil, sqlight.Error) {
  panic as "TODO: generated delete SQL"
}

/// Update a importedtrack by the `ByTitleAndArtist` identity.
pub fn update_importedtrack_by_title_and_artist(
  _conn: sqlight.Connection,
  _title: String,
  _artist: String,
  _file_path: option.Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated update SQL and decoding"
}

/// Get a importedtrack by the `ByTitleAndArtist` identity.
pub fn get_importedtrack_by_title_and_artist(
  _conn: sqlight.Connection,
  _title: String,
  _artist: String,
) -> Result(option.Option(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Upsert a importedtrack by the `ByTitleAndArtist` identity.
pub fn upsert_importedtrack_by_title_and_artist(
  _conn: sqlight.Connection,
  _title: String,
  _artist: String,
  _file_path: option.Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated upsert SQL and decoding"
}

/// List up to 100 recently edited tab rows.
pub fn last_100_edited_tab(
  _conn: sqlight.Connection,
) -> Result(List(#(Tab, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Delete a tab by the `ByTabLabel` identity.
pub fn delete_tab_by_tab_label(
  _conn: sqlight.Connection,
  _label: String,
) -> Result(Nil, sqlight.Error) {
  panic as "TODO: generated delete SQL"
}

/// Update a tab by the `ByTabLabel` identity.
pub fn update_tab_by_tab_label(
  _conn: sqlight.Connection,
  _label: String,
  _order: option.Option(Float),
  _view_config: option.Option(library_manager_advanced_schema.ViewConfigScalar),
) -> Result(#(Tab, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated update SQL and decoding"
}

/// Get a tab by the `ByTabLabel` identity.
pub fn get_tab_by_tab_label(
  _conn: sqlight.Connection,
  _label: String,
) -> Result(option.Option(#(Tab, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Upsert a tab by the `ByTabLabel` identity.
pub fn upsert_tab_by_tab_label(
  _conn: sqlight.Connection,
  _label: String,
  _order: option.Option(Float),
  _view_config: option.Option(library_manager_advanced_schema.ViewConfigScalar),
) -> Result(#(Tab, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated upsert SQL and decoding"
}

/// List up to 100 recently edited tag rows.
pub fn last_100_edited_tag(
  _conn: sqlight.Connection,
) -> Result(List(#(Tag, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Delete a tag by the `ByTagLabel` identity.
pub fn delete_tag_by_tag_label(
  _conn: sqlight.Connection,
  _label: String,
) -> Result(Nil, sqlight.Error) {
  panic as "TODO: generated delete SQL"
}

/// Update a tag by the `ByTagLabel` identity.
pub fn update_tag_by_tag_label(
  _conn: sqlight.Connection,
  _label: String,
  _emoji: option.Option(String),
) -> Result(#(Tag, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated update SQL and decoding"
}

/// Get a tag by the `ByTagLabel` identity.
pub fn get_tag_by_tag_label(
  _conn: sqlight.Connection,
  _label: String,
) -> Result(option.Option(#(Tag, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Upsert a tag by the `ByTagLabel` identity.
pub fn upsert_tag_by_tag_label(
  _conn: sqlight.Connection,
  _label: String,
  _emoji: option.Option(String),
) -> Result(#(Tag, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated upsert SQL and decoding"
}

/// List up to 100 recently edited trackbucket rows.
pub fn last_100_edited_trackbucket(
  _conn: sqlight.Connection,
) -> Result(List(#(TrackBucket, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Delete a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn delete_trackbucket_by_bucket_title_and_artist(
  _conn: sqlight.Connection,
  _title: String,
  _artist: String,
) -> Result(Nil, sqlight.Error) {
  panic as "TODO: generated delete SQL"
}

/// Update a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn update_trackbucket_by_bucket_title_and_artist(
  _conn: sqlight.Connection,
  _title: String,
  _artist: String,
) -> Result(#(TrackBucket, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated update SQL and decoding"
}

/// Get a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn get_trackbucket_by_bucket_title_and_artist(
  _conn: sqlight.Connection,
  _title: String,
  _artist: String,
) -> Result(option.Option(#(TrackBucket, dsl.MagicFields)), sqlight.Error) {
  panic as "TODO: generated select SQL and decoding"
}

/// Upsert a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn upsert_trackbucket_by_bucket_title_and_artist(
  _conn: sqlight.Connection,
  _title: String,
  _artist: String,
) -> Result(#(TrackBucket, dsl.MagicFields), sqlight.Error) {
  panic as "TODO: generated upsert SQL and decoding"
}

pub type QueryTabsForTabBarRow {
  QueryTabsForTabBarRow
}

/// Execute generated query for the `query_tabs_for_tab_bar` spec.
pub fn query_tabs_for_tab_bar(
  _conn: sqlight.Connection,
  _limit: Int,
) -> Result(List(QueryTabsForTabBarRow), sqlight.Error) {
  panic as "TODO: generated select SQL, parameters, and decoder"
}

pub type QueryTracksByViewConfigRow {
  QueryTracksByViewConfigRow
}

/// Execute generated query for the `query_tracks_by_view_config` spec.
pub fn query_tracks_by_view_config(
  _conn: sqlight.Connection,
  _complex_tag_filter_expression: library_manager_advanced_schema.FilterExpressionScalar,
) -> Result(List(QueryTracksByViewConfigRow), sqlight.Error) {
  panic as "TODO: generated select SQL, parameters, and decoder"
}
