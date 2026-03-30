import skwil/api_help
import case_studies/library_manager_db/row
import case_studies/library_manager_schema
import skwil/dsl/dsl
import gleam/dynamic/decode
import gleam/option
import gleam/result
import sqlight

const update_tab_by_id_sql = "update \"tab\" set \"label\" = ?, \"order\" = ?, \"view_config\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"label\", \"order\", \"view_config\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_tab_by_tab_label_sql = "update \"tab\" set \"order\" = ?, \"view_config\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null returning \"label\", \"order\", \"view_config\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_tab_by_tab_label_sql = "insert into \"tab\" (\"label\", \"order\", \"view_config\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"label\") do update set
  \"order\" = excluded.\"order\",
  \"view_config\" = excluded.\"view_config\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"label\", \"order\", \"view_config\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_trackbucket_by_id_sql = "update \"trackbucket\" set \"title\" = ?, \"artist\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_trackbucket_by_bucket_title_and_artist_sql = "update \"trackbucket\" set \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_trackbucket_by_bucket_title_and_artist_sql = "insert into \"trackbucket\" (\"title\", \"artist\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"title\", \"artist\") do update set
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_tag_by_id_sql = "update \"tag\" set \"label\" = ?, \"emoji\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"label\", \"emoji\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_tag_by_tag_label_sql = "update \"tag\" set \"emoji\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null returning \"label\", \"emoji\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_tag_by_tag_label_sql = "insert into \"tag\" (\"label\", \"emoji\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"label\") do update set
  \"emoji\" = excluded.\"emoji\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"label\", \"emoji\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_importedtrack_by_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"file_path\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_importedtrack_by_file_path_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"updated_at\" = ? where \"file_path\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_importedtrack_by_file_path_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"file_path\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"file_path\") do update set
  \"title\" = excluded.\"title\",
  \"artist\" = excluded.\"artist\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_importedtrack_by_title_and_artist_sql = "update \"importedtrack\" set \"file_path\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_importedtrack_by_title_and_artist_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"file_path\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"title\", \"artist\") do update set
  \"file_path\" = excluded.\"file_path\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

/// Update a tab by row id (all scalar columns, including natural-key fields).
pub fn update_tab_by_id(
  conn: sqlight.Connection,
  id: Int,
  label: option.Option(String),
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_label = api_help.opt_text_for_db(label)
  let db_order = api_help.opt_float_for_db(order)
  use rows <- result.try(sqlight.query(
    update_tab_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_label),
      sqlight.float(db_order),
      sqlight.text(row.view_config_scalar_to_db_string(view_config)),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.tab_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_tab_id_error("update_tab_by_id"))
  }
}

fn not_found_tab_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "tab" <> " not found: " <> op, -1)
}

/// Update a tab by the `ByTabLabel` identity.
pub fn update_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_order = api_help.opt_float_for_db(order)
  use rows <- result.try(sqlight.query(
    update_tab_by_tab_label_sql,
    on: conn,
    with: [
      sqlight.float(db_order),
      sqlight.text(row.view_config_scalar_to_db_string(view_config)),
      sqlight.int(now),
      sqlight.text(label),
    ],
    expecting: row.tab_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_tab_tab_label_error("update_tab_by_tab_label"))
  }
}

/// Upsert a tab by the `ByTabLabel` identity.
pub fn upsert_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
  order: option.Option(Float),
  view_config: option.Option(library_manager_schema.ViewConfigScalar),
) -> Result(#(library_manager_schema.Tab, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_order = api_help.opt_float_for_db(order)
  use rows <- result.try(sqlight.query(
    upsert_tab_by_tab_label_sql,
    on: conn,
    with: [
      sqlight.text(label),
      sqlight.float(db_order),
      sqlight.text(row.view_config_scalar_to_db_string(view_config)),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.tab_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

fn not_found_tab_tab_label_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "tab" <> " not found: " <> op, -1)
}

/// Update a trackbucket by row id (all scalar columns, including natural-key fields).
pub fn update_trackbucket_by_id(
  conn: sqlight.Connection,
  id: Int,
  title: option.Option(String),
  artist: option.Option(String),
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  let db_title = api_help.opt_text_for_db(title)
  let db_artist = api_help.opt_text_for_db(artist)
  use rows <- result.try(sqlight.query(
    update_trackbucket_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_title),
      sqlight.text(db_artist),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.trackbucket_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_trackbucket_id_error("update_trackbucket_by_id"))
  }
}

fn not_found_trackbucket_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "trackbucket" <> " not found: " <> op,
    -1,
  )
}

/// Update a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn update_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    update_trackbucket_by_bucket_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.int(now),
      sqlight.text(title),
      sqlight.text(artist),
    ],
    expecting: row.trackbucket_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(not_found_trackbucket_bucket_title_and_artist_error(
        "update_trackbucket_by_bucket_title_and_artist",
      ))
  }
}

/// Upsert a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn upsert_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(
  #(library_manager_schema.TrackBucket, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(sqlight.query(
    upsert_trackbucket_by_bucket_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.trackbucket_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

fn not_found_trackbucket_bucket_title_and_artist_error(
  op: String,
) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "trackbucket" <> " not found: " <> op,
    -1,
  )
}

/// Update a tag by row id (all scalar columns, including natural-key fields).
pub fn update_tag_by_id(
  conn: sqlight.Connection,
  id: Int,
  label: option.Option(String),
  emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_label = api_help.opt_text_for_db(label)
  let db_emoji = api_help.opt_text_for_db(emoji)
  use rows <- result.try(sqlight.query(
    update_tag_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_label),
      sqlight.text(db_emoji),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.tag_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_tag_id_error("update_tag_by_id"))
  }
}

fn not_found_tag_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "tag" <> " not found: " <> op, -1)
}

/// Update a tag by the `ByTagLabel` identity.
pub fn update_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
  emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_emoji = api_help.opt_text_for_db(emoji)
  use rows <- result.try(sqlight.query(
    update_tag_by_tag_label_sql,
    on: conn,
    with: [
      sqlight.text(db_emoji),
      sqlight.int(now),
      sqlight.text(label),
    ],
    expecting: row.tag_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_tag_tag_label_error("update_tag_by_tag_label"))
  }
}

/// Upsert a tag by the `ByTagLabel` identity.
pub fn upsert_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
  emoji: option.Option(String),
) -> Result(#(library_manager_schema.Tag, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let db_emoji = api_help.opt_text_for_db(emoji)
  use rows <- result.try(sqlight.query(
    upsert_tag_by_tag_label_sql,
    on: conn,
    with: [
      sqlight.text(label),
      sqlight.text(db_emoji),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.tag_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

fn not_found_tag_tag_label_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "tag" <> " not found: " <> op, -1)
}

/// Update a importedtrack by row id (all scalar columns, including natural-key fields).
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
  let now = api_help.unix_seconds_now()
  let db_title = api_help.opt_text_for_db(title)
  let db_artist = api_help.opt_text_for_db(artist)
  let db_file_path = api_help.opt_text_for_db(file_path)
  use rows <- result.try(sqlight.query(
    update_importedtrack_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_title),
      sqlight.text(db_artist),
      sqlight.text(db_file_path),
      sqlight.int(now),
      sqlight.int(id),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_importedtrack_id_error("update_importedtrack_by_id"))
  }
}

fn not_found_importedtrack_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}

/// Update a importedtrack by the `ByFilePath` identity.
pub fn update_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path: String,
  title: option.Option(String),
  artist: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  let db_title = api_help.opt_text_for_db(title)
  let db_artist = api_help.opt_text_for_db(artist)
  use rows <- result.try(sqlight.query(
    update_importedtrack_by_file_path_sql,
    on: conn,
    with: [
      sqlight.text(db_title),
      sqlight.text(db_artist),
      sqlight.int(now),
      sqlight.text(file_path),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(not_found_importedtrack_file_path_error(
        "update_importedtrack_by_file_path",
      ))
  }
}

/// Upsert a importedtrack by the `ByFilePath` identity.
pub fn upsert_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path: String,
  title: option.Option(String),
  artist: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  let db_title = api_help.opt_text_for_db(title)
  let db_artist = api_help.opt_text_for_db(artist)
  use rows <- result.try(sqlight.query(
    upsert_importedtrack_by_file_path_sql,
    on: conn,
    with: [
      sqlight.text(db_title),
      sqlight.text(db_artist),
      sqlight.text(file_path),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

fn not_found_importedtrack_file_path_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}

/// Update a importedtrack by the `ByTitleAndArtist` identity.
pub fn update_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  let db_file_path = api_help.opt_text_for_db(file_path)
  use rows <- result.try(sqlight.query(
    update_importedtrack_by_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(db_file_path),
      sqlight.int(now),
      sqlight.text(title),
      sqlight.text(artist),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(not_found_importedtrack_title_and_artist_error(
        "update_importedtrack_by_title_and_artist",
      ))
  }
}

/// Upsert a importedtrack by the `ByTitleAndArtist` identity.
pub fn upsert_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: option.Option(String),
) -> Result(
  #(library_manager_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  let db_file_path = api_help.opt_text_for_db(file_path)
  use rows <- result.try(sqlight.query(
    upsert_importedtrack_by_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
      sqlight.text(db_file_path),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

fn not_found_importedtrack_title_and_artist_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}

const upsert_trackbucket_tag_sql = "insert into \"trackbucket_tag\" (\"trackbucket_id\", \"tag_id\", \"value\") values (?, ?, ?) on conflict (\"trackbucket_id\", \"tag_id\") do update set \"value\" = excluded.\"value\";"

pub fn upsert_trackbucket_tag(
  conn: sqlight.Connection,
  trackbucket_id: Int,
  tag_id: Int,
  value: option.Option(Int),
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    upsert_trackbucket_tag_sql,
    on: conn,
    with: [
      sqlight.int(trackbucket_id),
      sqlight.int(tag_id),
      case value {
        option.Some(v) -> sqlight.int(v)
        option.None -> sqlight.null()
      },
    ],
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_) { Nil })
}
