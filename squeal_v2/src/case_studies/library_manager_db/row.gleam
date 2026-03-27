import api_help
import dsl/dsl as dsl
import case_studies/library_manager_schema.{type ViewConfigScalar, type TrackBucketRelationships, type TrackBucket, type TagExpressionScalar, type Tag, type Tab, type ImportedTrack, type FilterScalar, ViewConfigScalar, TrackBucketRelationships, TrackBucket, TagExpression, Tag, Tab, Or, Not, IsEqualTo, IsAtMost, IsAtLeast, ImportedTrack, Has, DoesNotHave, ByTitleAndArtist, ByTagLabel, ByTabLabel, ByFilePath, ByBucketTitleAndArtist, And}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}

pub fn view_config_scalar_from_db_string(s: String) -> Result(Option(ViewConfigScalar), String) {
  case json.parse(from: s, using: decode.optional(view_config_scalar_json_decoder())) {
  Ok(v) -> Ok(v)
  Error(_e) -> Error("Failed decoding ViewConfigScalar from JSON: " <> s)
}
}

pub fn view_config_scalar_to_db_string(o: Option(ViewConfigScalar)) -> String {
  case o {
  None -> "null"
    Some(ViewConfigScalar(filter_config:, source_selector:)) -> json.to_string(json.object([#("tag", json.string("ViewConfigScalar")), #("filter_config", json.nullable(filter_config, of: fn(x) { json.string(x) })), #("source_selector", json.nullable(source_selector, of: fn(x) { json.string(x) }))]))
}
}

fn view_config_scalar_json_decoder() -> decode.Decoder(ViewConfigScalar) {
  {
  use tag <- decode.field("tag", decode.string)
  case tag {
    "ViewConfigScalar" -> {
      use filter_config <- decode.field("filter_config", decode.optional(decode.string))
      use source_selector <- decode.field("source_selector", decode.optional(decode.string))
      decode.success(ViewConfigScalar(filter_config:, source_selector:))
    }
    _ -> decode.failure(ViewConfigScalar(filter_config: None, source_selector: None), expected: "ViewConfigScalar")
  }
}
}

pub fn tab_with_magic_row_decoder() -> decode.Decoder(#(Tab, dsl.MagicFields)) {
  use label <- decode.field(0, decode.string)
  use order <- decode.field(1, decode.float)
  use view_config <- decode.field(2, decode.then(decode.string, fn(s) {
    case view_config_scalar_from_db_string(s) {
      Ok(v) -> decode.success(v)
      Error(_) -> decode.failure(None, expected: "Option(ViewConfigScalar)")
    }
  }))
  use id <- decode.field(3, decode.int)
  use created_at <- decode.field(4, decode.int)
  use updated_at <- decode.field(5, decode.int)
  use deleted_at_raw <- decode.field(6, decode.optional(decode.int))
  let tab =
    Tab(
      label: Some(label),
      order: Some(order),
      view_config: view_config,
      tracks: [],
      identities: ByTabLabel(label:),
    )
  decode.success(#(
    tab,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn trackbucket_with_magic_row_decoder() -> decode.Decoder(#(TrackBucket, dsl.MagicFields)) {
  use title_raw <- decode.field(0, decode.string)
  use artist_raw <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let title = api_help.opt_string_from_db(title_raw)
  let artist = api_help.opt_string_from_db(artist_raw)
  let trackbucket =
    TrackBucket(
      title:,
      artist:,
      matched_tracks: [],
      identities: ByBucketTitleAndArtist(title: title_raw, artist: artist_raw),
      relationships: TrackBucketRelationships(
        tags: [],
      ),
    )
  decode.success(#(
    trackbucket,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn tag_with_magic_row_decoder() -> decode.Decoder(#(Tag, dsl.MagicFields)) {
  use label <- decode.field(0, decode.string)
  use emoji <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let tag =
    Tag(
      label: Some(label),
      emoji: api_help.opt_string_from_db(emoji),
      identities: ByTagLabel(label:),
    )
  decode.success(#(
    tag,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn importedtrack_with_magic_row_decoder() -> decode.Decoder(#(ImportedTrack, dsl.MagicFields)) {
  use title <- decode.field(0, decode.string)
  use artist <- decode.field(1, decode.string)
  use file_path <- decode.field(2, decode.string)
  use id <- decode.field(3, decode.int)
  use created_at <- decode.field(4, decode.int)
  use updated_at <- decode.field(5, decode.int)
  use deleted_at_raw <- decode.field(6, decode.optional(decode.int))
  let importedtrack =
    ImportedTrack(
      title: Some(title),
      artist: Some(artist),
      file_path: api_help.opt_string_from_db(file_path),
      tags: [],
      identities: ByTitleAndArtist(title:, artist:),
    )
  decode.success(#(
    importedtrack,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
