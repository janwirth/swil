import api_help
import dsl/dsl as dsl
import case_studies/library_manager_db/row
import case_studies/library_manager_schema.{type ViewConfigScalar, type TrackBucketRelationships, type TrackBucket, type TagExpressionScalar, type Tag, type Tab, type ImportedTrack, type FilterScalar, ViewConfigScalar, TrackBucketRelationships, TrackBucket, TagExpression, Tag, Tab, Or, Not, IsEqualTo, IsAtMost, IsAtLeast, ImportedTrack, Has, DoesNotHave, ByTitleAndArtist, ByTagLabel, ByTabLabel, ByFilePath, ByBucketTitleAndArtist, And}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import sqlight

const upsert_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"file_path\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"title\", \"artist\") do update set
  \"file_path\" = excluded.\"file_path\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_by_title_and_artist_sql = "update \"importedtrack\" set \"file_path\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

/// Update a importedtrack by the `ByTitleAndArtist` identity.
pub fn update_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let c = api_help.opt_text_for_db(file_path)
  use rows <- result.try(sqlight.query(
    update_by_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(c),
      sqlight.int(now),
      sqlight.text(title),
      sqlight.text(artist),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] -> Error(not_found_error("update_importedtrack_by_title_and_artist"))
  }
}

/// Upsert a importedtrack by the `ByTitleAndArtist` identity.
pub fn upsert_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  let now = api_help.unix_seconds_now()
  let c = api_help.opt_text_for_db(file_path)
  use rows <- result.try(sqlight.query(
    upsert_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
      sqlight.text(c),
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

fn not_found_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack"
    <>
    " not found: "
    <>
    op,
    -1,
  )
}
