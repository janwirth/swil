pub type ImportedtrackByTitleAndArtist {
  ImportedtrackByTitleAndArtist
}

pub type ImportedtrackByFilePath {
  ImportedtrackByFilePath
}

pub type ImportedtrackUpsertRow(by) {
  ImportedtrackUpsertRow(
    run: fn(sqlight.Connection) ->
      Result(
        #(library_manager_schema.ImportedTrack, dsl.MagicFields),
        sqlight.Error,
      ),
  )
}

fn run_importedtrack_upsert_row(
  row: ImportedtrackUpsertRow(by),
  conn: sqlight.Connection,
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let ImportedtrackUpsertRow(run:) = row
  run(conn)
}

pub type TagByTagLabel {
  TagByTagLabel
}

pub type TagUpsertRow(by) {
  TagUpsertRow(
    run: fn(sqlight.Connection) ->
      Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error),
  )
}

fn run_tag_upsert_row(
  row: TagUpsertRow(by),
  conn: sqlight.Connection,
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  let TagUpsertRow(run:) = row
  run(conn)
}

pub type TrackbucketByBucketTitleAndArtist {
  TrackbucketByBucketTitleAndArtist
}

pub type TrackbucketUpsertRow(by) {
  TrackbucketUpsertRow(
    run: fn(sqlight.Connection) ->
      Result(
        #(library_manager_schema.TrackBucket, dsl.MagicFields),
        sqlight.Error,
      ),
  )
}

fn run_trackbucket_upsert_row(
  row: TrackbucketUpsertRow(by),
  conn: sqlight.Connection,
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  let TrackbucketUpsertRow(run:) = row
  run(conn)
}

pub type TabByTabLabel {
  TabByTabLabel
}

pub type TabUpsertRow(by) {
  TabUpsertRow(
    run: fn(sqlight.Connection) ->
      Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error),
  )
}

fn run_tab_upsert_row(
  row: TabUpsertRow(by),
  conn: sqlight.Connection,
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  let TabUpsertRow(run:) = row
  run(conn)
}

import case_studies/library_manager_db/delete
import case_studies/library_manager_db/get
import case_studies/library_manager_db/migration
import case_studies/library_manager_db/query
import case_studies/library_manager_db/upsert
import case_studies/library_manager_schema
import gleam/list
import gleam/option
import sqlight
import swil/dsl/dsl

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
  id id: Int,
) -> Result(
  option.Option(#(library_manager_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tab_by_id(conn, id: id)
}

pub fn get_trackbucket_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_trackbucket_by_id(conn, id: id)
}

pub fn get_tag_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tag_by_id(conn, id: id)
}

pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_importedtrack_by_id(conn, id: id)
}

pub fn update_tab_by_id(
  conn: sqlight.Connection,
  id id: Int,
  label label: option.Option(String),
  order order: option.Option(Float),
  view_config view_config: option.Option(
    library_manager_schema.ViewConfigScalar,
  ),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  upsert.update_tab_by_id(
    conn,
    id: id,
    label: label,
    order: order,
    view_config: view_config,
  )
}

pub fn delete_tab_by_tab_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_tab_by_tab_label(conn, label: label)
}

pub fn update_tab_by_tab_label(
  conn: sqlight.Connection,
  label label: String,
  order order: option.Option(Float),
  view_config view_config: option.Option(
    library_manager_schema.ViewConfigScalar,
  ),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  upsert.update_tab_by_tab_label(
    conn,
    label: label,
    order: order,
    view_config: view_config,
  )
}

pub fn get_tab_by_tab_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(
  option.Option(#(library_manager_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tab_by_tab_label(conn, label: label)
}

pub fn by_tab_tab_label(
  label label: String,
  order order: option.Option(Float),
  view_config view_config: option.Option(
    library_manager_schema.ViewConfigScalar,
  ),
) -> TabUpsertRow(TabByTabLabel) {
  TabUpsertRow(fn(conn) {
    upsert.upsert_tab_by_tab_label(
      conn,
      label: label,
      order: order,
      view_config: view_config,
    )
  })
}

pub fn upsert_many_tab(
  conn: sqlight.Connection,
  rows rows: List(TabUpsertRow(by)),
) -> Result(List(#(library_manager_schema.Tab, dsl.MagicFields)), sqlight.Error) {
  list.try_map(rows, fn(row) { run_tab_upsert_row(row, conn) })
}

pub fn upsert_one_tab(
  conn: sqlight.Connection,
  row row: TabUpsertRow(by),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  run_tab_upsert_row(row, conn)
}

pub fn update_trackbucket_by_id(
  conn: sqlight.Connection,
  id id: Int,
  title title: option.Option(String),
  artist artist: option.Option(String),
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_trackbucket_by_id(conn, id: id, title: title, artist: artist)
}

pub fn delete_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_trackbucket_by_bucket_title_and_artist(
    conn,
    title: title,
    artist: artist,
  )
}

pub fn update_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_trackbucket_by_bucket_title_and_artist(
    conn,
    title: title,
    artist: artist,
  )
}

pub fn get_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(
  option.Option(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_trackbucket_by_bucket_title_and_artist(
    conn,
    title: title,
    artist: artist,
  )
}

pub fn by_trackbucket_bucket_title_and_artist(
  title title: String,
  artist artist: String,
) -> TrackbucketUpsertRow(TrackbucketByBucketTitleAndArtist) {
  TrackbucketUpsertRow(fn(conn) {
    upsert.upsert_trackbucket_by_bucket_title_and_artist(
      conn,
      title: title,
      artist: artist,
    )
  })
}

pub fn upsert_many_trackbucket(
  conn: sqlight.Connection,
  rows rows: List(TrackbucketUpsertRow(by)),
) -> Result(
  List(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(rows, fn(row) { run_trackbucket_upsert_row(row, conn) })
}

pub fn upsert_one_trackbucket(
  conn: sqlight.Connection,
  row row: TrackbucketUpsertRow(by),
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  run_trackbucket_upsert_row(row, conn)
}

pub fn update_tag_by_id(
  conn: sqlight.Connection,
  id id: Int,
  label label: option.Option(String),
  emoji emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  upsert.update_tag_by_id(conn, id: id, label: label, emoji: emoji)
}

pub fn delete_tag_by_tag_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_tag_by_tag_label(conn, label: label)
}

pub fn update_tag_by_tag_label(
  conn: sqlight.Connection,
  label label: String,
  emoji emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  upsert.update_tag_by_tag_label(conn, label: label, emoji: emoji)
}

pub fn get_tag_by_tag_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(
  option.Option(#(library_manager_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_tag_by_tag_label(conn, label: label)
}

pub fn by_tag_tag_label(
  label label: String,
  emoji emoji: option.Option(String),
) -> TagUpsertRow(TagByTagLabel) {
  TagUpsertRow(fn(conn) {
    upsert.upsert_tag_by_tag_label(conn, label: label, emoji: emoji)
  })
}

pub fn upsert_many_tag(
  conn: sqlight.Connection,
  rows rows: List(TagUpsertRow(by)),
) -> Result(List(#(library_manager_schema.Tag, dsl.MagicFields)), sqlight.Error) {
  list.try_map(rows, fn(row) { run_tag_upsert_row(row, conn) })
}

pub fn upsert_one_tag(
  conn: sqlight.Connection,
  row row: TagUpsertRow(by),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  run_tag_upsert_row(row, conn)
}

pub fn update_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
  title title: option.Option(String),
  artist artist: option.Option(String),
  file_path file_path: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_importedtrack_by_id(
    conn,
    id: id,
    title: title,
    artist: artist,
    file_path: file_path,
  )
}

pub fn delete_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path file_path: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_importedtrack_by_file_path(conn, file_path: file_path)
}

pub fn update_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path file_path: String,
  title title: option.Option(String),
  artist artist: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_importedtrack_by_file_path(
    conn,
    file_path: file_path,
    title: title,
    artist: artist,
  )
}

pub fn get_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path file_path: String,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_importedtrack_by_file_path(conn, file_path: file_path)
}

pub fn by_importedtrack_file_path(
  file_path file_path: String,
  title title: option.Option(String),
  artist artist: option.Option(String),
) -> ImportedtrackUpsertRow(ImportedtrackByFilePath) {
  ImportedtrackUpsertRow(fn(conn) {
    upsert.upsert_importedtrack_by_file_path(
      conn,
      file_path: file_path,
      title: title,
      artist: artist,
    )
  })
}

pub fn delete_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_importedtrack_by_title_and_artist(
    conn,
    title: title,
    artist: artist,
  )
}

pub fn update_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
  file_path file_path: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.update_importedtrack_by_title_and_artist(
    conn,
    title: title,
    artist: artist,
    file_path: file_path,
  )
}

pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(
  option.Option(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_importedtrack_by_title_and_artist(conn, title: title, artist: artist)
}

pub fn by_importedtrack_title_and_artist(
  title title: String,
  artist artist: String,
  file_path file_path: option.Option(String),
) -> ImportedtrackUpsertRow(ImportedtrackByTitleAndArtist) {
  ImportedtrackUpsertRow(fn(conn) {
    upsert.upsert_importedtrack_by_title_and_artist(
      conn,
      title: title,
      artist: artist,
      file_path: file_path,
    )
  })
}

pub fn upsert_many_importedtrack(
  conn: sqlight.Connection,
  rows rows: List(ImportedtrackUpsertRow(by)),
) -> Result(
  List(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(rows, fn(row) { run_importedtrack_upsert_row(row, conn) })
}

pub fn upsert_one_importedtrack(
  conn: sqlight.Connection,
  row row: ImportedtrackUpsertRow(by),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  run_importedtrack_upsert_row(row, conn)
}
