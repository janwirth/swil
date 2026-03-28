//// Row decoders for `library_manager_advanced_db`.
////
//// Each `*_with_magic_row_decoder` decodes positional columns returned by
//// the SELECT queries in `query.gleam`.  The column order matches the SQL.

import api_help
import case_studies/library_manager_advanced_schema as schema
import dsl/dsl
import gleam/dynamic/decode
import gleam/option

pub fn trackbucket_with_magic_row_decoder() -> decode.Decoder(
  #(schema.TrackBucket, dsl.MagicFields),
) {
  use title_raw <- decode.field(0, decode.string)
  use artist_raw <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let title = api_help.opt_string_from_db(title_raw)
  let artist = api_help.opt_string_from_db(artist_raw)
  let trackbucket =
    schema.TrackBucket(
      title:,
      artist:,
      matched_tracks: [],
      identities: schema.ByBucketTitleAndArtist(
        title: title_raw,
        artist: artist_raw,
      ),
      relationships: schema.TrackBucketRelationships(tags: []),
    )
  decode.success(#(
    trackbucket,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn tag_with_magic_row_decoder() -> decode.Decoder(
  #(schema.Tag, dsl.MagicFields),
) {
  use label <- decode.field(0, decode.string)
  use emoji_raw <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let tag =
    schema.Tag(
      label: option.Some(label),
      emoji: api_help.opt_string_from_db(emoji_raw),
      identities: schema.ByTagLabel(label:),
    )
  decode.success(#(
    tag,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
