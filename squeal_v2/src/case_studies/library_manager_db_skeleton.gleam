import case_studies/library_manager_schema.{
  type ImportedTrack, type Tab, type Tag, type TrackBucket,
}
import gleam/option
import sqlight

/// Generated from `case_studies/library_manager_schema`.
///
/// Table of contents:
/// - `migrate/1`
/// - Entity ops: ImportedTrack, Tab, Tag, TrackBucket
/// - Query specs: none
pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated migration SQL"
}

/// Upsert a importedtrack by the `ByTitleAndArtist` identity.
pub fn upsert_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: option.Option(String),
) -> Result(ImportedTrack, sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// Get a importedtrack by the `ByTitleAndArtist` identity.
pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(option.Option(ImportedTrack), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Update a importedtrack by the `ByTitleAndArtist` identity.
pub fn update_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: option.Option(String),
) -> Result(ImportedTrack, sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Delete a importedtrack by the `ByTitleAndArtist` identity.
pub fn delete_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// Upsert a tab by the `ByTabLabel` identity.
pub fn upsert_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(Tab, sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// Get a tab by the `ByTabLabel` identity.
pub fn get_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(option.Option(Tab), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Update a tab by the `ByTabLabel` identity.
pub fn update_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(Tab, sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Delete a tab by the `ByTabLabel` identity.
pub fn delete_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// Upsert a tag by the `ByTagLabel` identity.
pub fn upsert_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
  emoji: option.Option(String),
) -> Result(Tag, sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// Get a tag by the `ByTagLabel` identity.
pub fn get_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(option.Option(Tag), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Update a tag by the `ByTagLabel` identity.
pub fn update_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
  emoji: option.Option(String),
) -> Result(Tag, sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Delete a tag by the `ByTagLabel` identity.
pub fn delete_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}

/// Upsert a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn upsert_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(TrackBucket, sqlight.Error) {
  todo as "TODO: generated upsert SQL and decoding"
}

/// Get a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn get_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(option.Option(TrackBucket), sqlight.Error) {
  todo as "TODO: generated select SQL and decoding"
}

/// Update a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn update_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(TrackBucket, sqlight.Error) {
  todo as "TODO: generated update SQL and decoding"
}

/// Delete a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn delete_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Nil, sqlight.Error) {
  todo as "TODO: generated delete SQL"
}
