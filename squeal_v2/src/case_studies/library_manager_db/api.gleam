import case_studies/library_manager_db/delete
import dsl/dsl as dsl
import case_studies/library_manager_db/get
import case_studies/library_manager_db/migration
import case_studies/library_manager_db/query
import case_studies/library_manager_db/row
import case_studies/library_manager_db/upsert
import case_studies/library_manager_schema.{type ViewConfigScalar, type TrackBucketRelationships, type TrackBucket, type TagExpressionScalar, type Tag, type Tab, type ImportedTrack, type FilterScalar, ViewConfigScalar, TrackBucketRelationships, TrackBucket, TagExpression, Tag, Tab, Or, Not, IsEqualTo, IsAtMost, IsAtLeast, ImportedTrack, Has, DoesNotHave, ByTitleAndArtist, ByTagLabel, ByTabLabel, ByFilePath, ByBucketTitleAndArtist, And}
import gleam/option.{type Option, None, Some}
import gleam/result
import sqlight

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn last_100_edited_tab(conn: sqlight.Connection) -> Result(
  List(#(Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_tab(conn)
}

pub fn last_100_edited_trackbucket(conn: sqlight.Connection) -> Result(
  List(#(TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_trackbucket(conn)
}

pub fn last_100_edited_tag(conn: sqlight.Connection) -> Result(
  List(#(Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_tag(conn)
}

pub fn last_100_edited_importedtrack(conn: sqlight.Connection) -> Result(
  List(#(ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_importedtrack(conn)
}

pub fn delete_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_importedtrack_by_title_and_artist(conn, title, artist)
}

pub fn update_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  upsert.update_importedtrack_by_title_and_artist(conn, title, artist, file_path)
}

pub fn get_tab_by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tab_by_id(conn, id)
}

pub fn get_trackbucket_by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_trackbucket_by_id(conn, id)
}

pub fn get_tag_by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tag_by_id(conn, id)
}

pub fn get_importedtrack_by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_importedtrack_by_id(conn, id)
}

pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Option(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  get.get_importedtrack_by_title_and_artist(conn, title, artist)
}

pub fn upsert_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_importedtrack_by_title_and_artist(conn, title, artist, file_path)
}
