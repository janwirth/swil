import case_studies/library_manager_schema.{
  type ImportedTrack, type Tab, type Tag, type TrackBucket,
}
import dsl/dsl as dsl
import gleam/option
import sqlight

/// Generated from `case_studies/library_manager_schema`.
///
/// Table of contents:
/// - `migrate/1`
/// - Entity ops: ImportedTrack, Tab, Tag, TrackBucket
/// - Query specs: `query_tabs_for_tab_bar`
pub fn migrate(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated migration SQL"
}

/// List up to 100 recently edited importedtrack rows.
pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(List(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Delete a importedtrack by the `ByTitleAndArtist` identity.
pub fn delete_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// Update a importedtrack by the `ByTitleAndArtist` identity.
pub fn update_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: option.Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Get a importedtrack by the `ByTitleAndArtist` identity.
pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(option.Option(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Upsert a importedtrack by the `ByTitleAndArtist` identity.
pub fn upsert_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: option.Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// List up to 100 recently edited tab rows.
pub fn last_100_edited_tab(
  conn: sqlight.Connection,
) -> Result(List(#(Tab, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Delete a tab by the `ByTabLabel` identity.
pub fn delete_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// Update a tab by the `ByTabLabel` identity.
pub fn update_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(#(Tab, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Get a tab by the `ByTabLabel` identity.
pub fn get_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(option.Option(#(Tab, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Upsert a tab by the `ByTabLabel` identity.
pub fn upsert_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(#(Tab, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// List up to 100 recently edited tag rows.
pub fn last_100_edited_tag(
  conn: sqlight.Connection,
) -> Result(List(#(Tag, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Delete a tag by the `ByTagLabel` identity.
pub fn delete_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// Update a tag by the `ByTagLabel` identity.
pub fn update_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
  emoji: option.Option(String),
) -> Result(#(Tag, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Get a tag by the `ByTagLabel` identity.
pub fn get_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(option.Option(#(Tag, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Upsert a tag by the `ByTagLabel` identity.
pub fn upsert_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
  emoji: option.Option(String),
) -> Result(#(Tag, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// List up to 100 recently edited trackbucket rows.
pub fn last_100_edited_trackbucket(
  conn: sqlight.Connection,
) -> Result(List(#(TrackBucket, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Delete a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn delete_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// Update a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn update_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(#(TrackBucket, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Get a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn get_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(option.Option(#(TrackBucket, dsl.MagicFields)), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Upsert a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn upsert_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(#(TrackBucket, dsl.MagicFields), sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

pub type QueryTabsForTabBarRow {
  QueryTabsForTabBarRow
}

/// Execute generated query for the `query_tabs_for_tab_bar` spec.
pub fn query_tabs_for_tab_bar(
  conn: sqlight.Connection,
  limit: Int,
) -> Result(List(QueryTabsForTabBarRow), sqlight.Error) {
  todo as "TODO: generated select SQL, parameters, and decoder"
}
