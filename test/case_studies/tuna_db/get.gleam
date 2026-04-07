import case_studies/tuna_db/row.{
  type ImportedTrackRow, type TagRow, type TrackBucketRow,
}
import case_studies/tuna_schema
import gleam/option
import gleam/result
import sqlight
import swil/dsl

const select_tag_by_id_sql = "select \"label\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"id\" = ? and \"deleted_at\" is null;"

const select_tag_by_label_sql = "select \"label\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"label\" = ? and \"deleted_at\" is null;"

const select_trackbucket_by_id_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"id\" = ? and \"deleted_at\" is null;"

const select_trackbucket_by_title_and_artist_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const select_importedtrack_by_id_sql = "select \"from_source_root\", \"title\", \"artist\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"id\" = ? and \"deleted_at\" is null;"

const select_importedtrack_by_service_and_source_id_sql = "select \"from_source_root\", \"title\", \"artist\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"from_source_root\" = ? and \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"

/// Get a tag by row id.
pub fn get_tag_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(option.Option(#(TagRow, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_tag_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.tag_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a tag by the `ByLabel` identity.
pub fn get_tag_by_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(option.Option(#(TagRow, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_tag_by_label_sql,
    on: conn,
    with: [sqlight.text(label)],
    expecting: row.tag_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a trackbucket by row id.
pub fn get_trackbucket_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(option.Option(#(TrackBucketRow, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_trackbucket_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.trackbucket_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a trackbucket by the `ByTitleAndArtist` identity.
pub fn get_trackbucket_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(option.Option(#(TrackBucketRow, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_trackbucket_by_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
    ],
    expecting: row.trackbucket_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a importedtrack by row id.
pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(option.Option(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_importedtrack_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Get a importedtrack by the `ByServiceAndSourceId` identity.
pub fn get_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  from_source_root from_source_root: String,
  service service: String,
  source_id source_id: String,
) -> Result(option.Option(#(ImportedTrackRow, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_importedtrack_by_service_and_source_id_sql,
    on: conn,
    with: [
      sqlight.text(from_source_root),
      sqlight.text(service),
      sqlight.text(source_id),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}
