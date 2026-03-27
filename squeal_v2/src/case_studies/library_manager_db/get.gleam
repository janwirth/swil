import api_help
import dsl/dsl as dsl
import case_studies/library_manager_db/row
import case_studies/library_manager_schema.{type ViewConfigScalar, type TrackBucketRelationships, type TrackBucket, type TagExpressionScalar, type Tag, type Tab, type ImportedTrack, type FilterScalar, ViewConfigScalar, TrackBucketRelationships, TrackBucket, TagExpression, Tag, Tab, Or, Not, IsEqualTo, IsAtMost, IsAtLeast, ImportedTrack, Has, DoesNotHave, ByTitleAndArtist, ByTagLabel, ByTabLabel, ByFilePath, ByBucketTitleAndArtist, And}
import gleam/option.{type Option, None, Some}
import gleam/result
import sqlight

const select_tab_by_id_sql = "select \"label\", \"order\", \"view_config\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tab\" where \"id\" = ? and \"deleted_at\" is null;"

const select_tab_by_tab_label_sql = "select \"label\", \"order\", \"view_config\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tab\" where \"label\" = ? and \"deleted_at\" is null;"

const select_trackbucket_by_id_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"id\" = ? and \"deleted_at\" is null;"

const select_trackbucket_by_bucket_title_and_artist_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const select_tag_by_id_sql = "select \"label\", \"emoji\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"id\" = ? and \"deleted_at\" is null;"

const select_tag_by_tag_label_sql = "select \"label\", \"emoji\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"label\" = ? and \"deleted_at\" is null;"

const select_importedtrack_by_id_sql = "select \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"id\" = ? and \"deleted_at\" is null;"

const select_importedtrack_by_title_and_artist_sql = "select \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

/// Get a tab by row id.
pub fn get_tab_by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_tab_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.tab_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}

/// Get a tab by the `ByTabLabel` identity.
pub fn get_tab_by_tab_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(Option(#(Tab, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_tab_by_tab_label_sql,
    on: conn,
    with: [sqlight.text(label)],
    expecting: row.tab_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}

/// Get a trackbucket by row id.
pub fn get_trackbucket_by_id(
  conn: sqlight.Connection,
  id: Int,
) -> Result(Option(#(TrackBucket, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_trackbucket_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.trackbucket_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}

/// Get a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn get_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Option(#(TrackBucket, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_trackbucket_by_bucket_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
    ],
    expecting: row.trackbucket_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}

/// Get a tag by row id.
pub fn get_tag_by_id(conn: sqlight.Connection, id: Int) -> Result(
  Option(#(Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  use rows <- result.try(sqlight.query(
    select_tag_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.tag_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}

/// Get a tag by the `ByTagLabel` identity.
pub fn get_tag_by_tag_label(
  conn: sqlight.Connection,
  label: String,
) -> Result(Option(#(Tag, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_tag_by_tag_label_sql,
    on: conn,
    with: [sqlight.text(label)],
    expecting: row.tag_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}

/// Get a importedtrack by row id.
pub fn get_importedtrack_by_id(
  conn: sqlight.Connection,
  id: Int,
) -> Result(Option(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_importedtrack_by_id_sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}

/// Get a importedtrack by the `ByTitleAndArtist` identity.
pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Option(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_importedtrack_by_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [r, ..] -> Ok(Some(r))
  }
}
