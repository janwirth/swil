pub type ImportedTrackRow {
  ImportedTrackRow(
    from_source_root: option.Option(String),
    title: option.Option(String),
    artist: option.Option(String),
    file_path: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
    tags: List(#(tuna_schema.Tag, tuna_schema.AppliedTagRelationshipAttributes)),
    track_bucket: option.Option(tuna_schema.TrackBucket),
  )
}

pub type TrackBucketRow {
  TrackBucketRow(title: option.Option(String), artist: option.Option(String))
}

pub type TagRow {
  TagRow(label: option.Option(String))
}

import from_usage/one/tuna_schema
import gleam/dynamic/decode
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import swil/dsl
import swil/runtime/api_help

pub fn tag_with_magic_row_decoder() -> decode.Decoder(
  #(TagRow, dsl.MagicFields),
) {
  use label <- decode.field(0, decode.string)
  use id <- decode.field(1, decode.int)
  use created_at <- decode.field(2, decode.int)
  use updated_at <- decode.field(3, decode.int)
  use deleted_at_raw <- decode.field(4, decode.optional(decode.int))
  let tag_row = TagRow(label: option.Some(label))
  decode.success(#(
    tag_row,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn trackbucket_with_magic_row_decoder() -> decode.Decoder(
  #(TrackBucketRow, dsl.MagicFields),
) {
  use title <- decode.field(0, decode.string)
  use artist <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let trackbucket_row =
    TrackBucketRow(title: option.Some(title), artist: option.Some(artist))
  decode.success(#(
    trackbucket_row,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn importedtrack_with_magic_row_decoder() -> decode.Decoder(
  #(ImportedTrackRow, dsl.MagicFields),
) {
  use from_source_root_raw <- decode.field(0, decode.optional(decode.string))
  use title_raw <- decode.field(1, decode.optional(decode.string))
  use artist_raw <- decode.field(2, decode.optional(decode.string))
  use file_path_raw <- decode.field(3, decode.optional(decode.string))
  use service_raw <- decode.field(4, decode.optional(decode.string))
  use source_id_raw <- decode.field(5, decode.optional(decode.string))
  use added_to_library_at_raw <- decode.field(6, decode.int)
  use external_source_url_raw <- decode.field(7, decode.optional(decode.string))
  use id <- decode.field(8, decode.int)
  use created_at <- decode.field(9, decode.int)
  use updated_at <- decode.field(10, decode.int)
  use deleted_at_raw <- decode.field(11, decode.optional(decode.int))
  let from_source_root = api_help.option_string_from_optional_db(from_source_root_raw)
  let title = api_help.option_string_from_optional_db(title_raw)
  let artist = api_help.option_string_from_optional_db(artist_raw)
  let file_path = api_help.option_string_from_optional_db(file_path_raw)
  let service = api_help.option_string_from_optional_db(service_raw)
  let source_id = api_help.option_string_from_optional_db(source_id_raw)
  let added_to_library_at =
    api_help.opt_timestamp_from_db(added_to_library_at_raw)
  let external_source_url = api_help.option_string_from_optional_db(external_source_url_raw)
  let importedtrack_row =
    ImportedTrackRow(
      from_source_root:,
      title:,
      artist:,
      file_path:,
      service:,
      source_id:,
      added_to_library_at:,
      external_source_url:,
      tags: [],
      track_bucket: option.None,
    )
  decode.success(#(
    importedtrack_row,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
