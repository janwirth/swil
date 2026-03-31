import case_studies/library_manager_db/delete
import case_studies/library_manager_db/get
import case_studies/library_manager_db/migration
import case_studies/library_manager_db/query
import case_studies/library_manager_db/upsert
import case_studies/library_manager_schema
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

pub fn upsert_many_tab_by_tab_label(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    sqlight.Connection,
    a,
    fn(
      sqlight.Connection,
      String,
      option.Option(Float),
      option.Option(library_manager_schema.ViewConfigScalar),
    ) ->
      Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error),
) -> Result(List(#(library_manager_schema.Tab, dsl.MagicFields)), sqlight.Error) {
  upsert.upsert_many_tab_by_tab_label(conn, items: items, each: each)
}

pub fn upsert_tab_by_tab_label(
  conn: sqlight.Connection,
  label label: String,
  order order: option.Option(Float),
  view_config view_config: option.Option(
    library_manager_schema.ViewConfigScalar,
  ),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_tab_by_tab_label(
    conn,
    label: label,
    order: order,
    view_config: view_config,
  )
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

pub fn upsert_many_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    sqlight.Connection,
    a,
    fn(sqlight.Connection, String, String) ->
      Result(
        #(library_manager_schema.TrackBucket, dsl.MagicFields),
        sqlight.Error,
      ),
  ) ->
    Result(
      #(library_manager_schema.TrackBucket, dsl.MagicFields),
      sqlight.Error,
    ),
) -> Result(
  List(#(library_manager_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  upsert.upsert_many_trackbucket_by_bucket_title_and_artist(
    conn,
    items: items,
    each: each,
  )
}

pub fn upsert_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.upsert_trackbucket_by_bucket_title_and_artist(
    conn,
    title: title,
    artist: artist,
  )
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

pub fn upsert_many_tag_by_tag_label(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    sqlight.Connection,
    a,
    fn(sqlight.Connection, String, option.Option(String)) ->
      Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error),
) -> Result(List(#(library_manager_schema.Tag, dsl.MagicFields)), sqlight.Error) {
  upsert.upsert_many_tag_by_tag_label(conn, items: items, each: each)
}

pub fn upsert_tag_by_tag_label(
  conn: sqlight.Connection,
  label label: String,
  emoji emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  upsert.upsert_tag_by_tag_label(conn, label: label, emoji: emoji)
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

pub fn upsert_many_importedtrack_by_file_path(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    sqlight.Connection,
    a,
    fn(sqlight.Connection, String, option.Option(String), option.Option(String)) ->
      Result(
        #(library_manager_schema.ImportedTrack, dsl.MagicFields),
        sqlight.Error,
      ),
  ) ->
    Result(
      #(library_manager_schema.ImportedTrack, dsl.MagicFields),
      sqlight.Error,
    ),
) -> Result(
  List(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  upsert.upsert_many_importedtrack_by_file_path(conn, items: items, each: each)
}

pub fn upsert_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path file_path: String,
  title title: option.Option(String),
  artist artist: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.upsert_importedtrack_by_file_path(
    conn,
    file_path: file_path,
    title: title,
    artist: artist,
  )
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

pub fn upsert_many_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    sqlight.Connection,
    a,
    fn(sqlight.Connection, String, String, option.Option(String)) ->
      Result(
        #(library_manager_schema.ImportedTrack, dsl.MagicFields),
        sqlight.Error,
      ),
  ) ->
    Result(
      #(library_manager_schema.ImportedTrack, dsl.MagicFields),
      sqlight.Error,
    ),
) -> Result(
  List(#(library_manager_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  upsert.upsert_many_importedtrack_by_title_and_artist(
    conn,
    items: items,
    each: each,
  )
}

pub fn upsert_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
  file_path file_path: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  upsert.upsert_importedtrack_by_title_and_artist(
    conn,
    title: title,
    artist: artist,
    file_path: file_path,
  )
}
