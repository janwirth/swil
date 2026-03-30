import case_studies/library_manager_db/delete
import case_studies/library_manager_db/get
import case_studies/library_manager_db/migration
import case_studies/library_manager_db/query
import case_studies/library_manager_db/upsert
import case_studies/library_manager_schema
import skwil/dsl/dsl
import gleam/option
import sqlight

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn last_100_edited_tab(
  conn: sqlight.Connection,
) -> Result(List(#(library_manager_schema.Tab, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_tab(conn)
}

pub fn last_100_edited_trackbucket(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_trackbucket(conn)
}

pub fn last_100_edited_tag(
  conn: sqlight.Connection,
) -> Result(List(#(library_manager_schema.Tag, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_tag(conn)
}

pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_importedtrack(conn)
}

pub fn get_tab_by_id(
  conn: sqlight.Connection,
  id: Int,
) -> Result(
  option.Option(#(library_manager_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tab_by_id(conn, id)
}

pub fn get_trackbucket_by_id(
  conn: sqlight.Connection,
  id: Int,
) -> Result(
  option.Option(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_trackbucket_by_id(conn, id)
}

pub fn get_tag_by_id(
  conn: sqlight.Connection,
  id: Int,
) -> Result(
  option.Option(#(library_manager_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tag_by_id(conn, id)
}

pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id: Int,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_importedtrack_by_id(conn, id)
}

pub fn update_tab_by_id(
  conn: sqlight.Connection,
  id: Int,
  label: option.Option(String),
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  upsert.update_tab_by_id(conn, id, label, order, view_config)
}

pub fn delete_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_tab_by_tab_label(conn, label)
}

pub fn update_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  upsert.update_tab_by_tab_label(conn, label, order, view_config)
}

pub fn get_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(
  option.Option(#(library_manager_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tab_by_tab_label(conn, label)
}

pub fn upsert_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_tab_by_tab_label(conn, label, order, view_config)
}

pub fn update_trackbucket_by_id(
  conn: sqlight.Connection,
  id: Int,
  title: option.Option(String),
  artist: option.Option(String),
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_trackbucket_by_id(conn, id, title, artist)
}

pub fn delete_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_trackbucket_by_bucket_title_and_artist(conn, title, artist)
}

pub fn update_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_trackbucket_by_bucket_title_and_artist(conn, title, artist)
}

pub fn get_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(
  option.Option(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_trackbucket_by_bucket_title_and_artist(conn, title, artist)
}

pub fn upsert_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.upsert_trackbucket_by_bucket_title_and_artist(conn, title, artist)
}

pub fn update_tag_by_id(
  conn: sqlight.Connection,
  id: Int,
  label: option.Option(String),
  emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  upsert.update_tag_by_id(conn, id, label, emoji)
}

pub fn delete_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_tag_by_tag_label(conn, label)
}

pub fn update_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
  emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  upsert.update_tag_by_tag_label(conn, label, emoji)
}

pub fn get_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(
  option.Option(#(library_manager_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tag_by_tag_label(conn, label)
}

pub fn upsert_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
  emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_tag_by_tag_label(conn, label, emoji)
}

pub fn update_importedtrack_by_id(
  conn: sqlight.Connection,
  id: Int,
  title: option.Option(String),
  artist: option.Option(String),
  file_path: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_importedtrack_by_id(conn, id, title, artist, file_path)
}

pub fn delete_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_importedtrack_by_file_path(conn, file_path)
}

pub fn update_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path: String,
  title: option.Option(String),
  artist: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_importedtrack_by_file_path(conn, file_path, title, artist)
}

pub fn get_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path: String,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_importedtrack_by_file_path(conn, file_path)
}

pub fn upsert_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path: String,
  title: option.Option(String),
  artist: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.upsert_importedtrack_by_file_path(conn, file_path, title, artist)
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
  file_path: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_importedtrack_by_title_and_artist(
    conn,
    title,
    artist,
    file_path,
  )
}

pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_importedtrack_by_title_and_artist(conn, title, artist)
}

pub fn upsert_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.upsert_importedtrack_by_title_and_artist(
    conn,
    title,
    artist,
    file_path,
  )
}
