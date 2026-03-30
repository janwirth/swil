import api_help
import case_studies/library_manager_advanced_schema
import dsl/dsl
import gleam/dynamic/decode
import gleam/json
import gleam/option

pub fn view_config_scalar_from_db_string(
  s: String,
) -> Result(
  option.Option(library_manager_advanced_schema.ViewConfigScalar),
  String,
) {
  case
    json.parse(
      from: s,
      using: decode.optional(view_config_scalar_json_decoder()),
    )
  {
    Ok(v) -> Ok(v)
    Error(_e) -> Error("Failed decoding ViewConfigScalar from JSON: " <> s)
  }
}

pub fn view_config_scalar_to_db_string(
  o: option.Option(library_manager_advanced_schema.ViewConfigScalar),
) -> String {
  case o {
    option.None -> "null"
    option.Some(library_manager_advanced_schema.ViewConfigScalar(
      filter_config:,
      source_selector:,
    )) ->
      json.to_string(
        json.object([
          #("tag", json.string("ViewConfigScalar")),
          #(
            "filter_config",
            json.nullable(filter_config, of: fn(x) { json.string(x) }),
          ),
          #(
            "source_selector",
            json.nullable(source_selector, of: fn(x) { json.string(x) }),
          ),
        ]),
      )
  }
}

fn view_config_scalar_json_decoder() -> decode.Decoder(
  library_manager_advanced_schema.ViewConfigScalar,
) {
  {
    use tag <- decode.field("tag", decode.string)
    case tag {
      "ViewConfigScalar" -> {
        use filter_config <- decode.field(
          "filter_config",
          decode.optional(decode.string),
        )
        use source_selector <- decode.field(
          "source_selector",
          decode.optional(decode.string),
        )
        decode.success(library_manager_advanced_schema.ViewConfigScalar(
          filter_config:,
          source_selector:,
        ))
      }
      _ ->
        decode.failure(
          library_manager_advanced_schema.ViewConfigScalar(
            filter_config: option.None,
            source_selector: option.None,
          ),
          expected: "ViewConfigScalar",
        )
    }
  }
}

pub fn tab_with_magic_row_decoder() -> decode.Decoder(
  #(library_manager_advanced_schema.Tab, dsl.MagicFields),
) {
  use label <- decode.field(0, decode.string)
  use order <- decode.field(1, decode.float)
  use view_config <- decode.field(
    2,
    decode.then(decode.string, fn(s) {
      case view_config_scalar_from_db_string(s) {
        Ok(v) -> decode.success(v)
        Error(_) ->
          decode.failure(option.None, expected: "Option(ViewConfigScalar)")
      }
    }),
  )
  use id <- decode.field(3, decode.int)
  use created_at <- decode.field(4, decode.int)
  use updated_at <- decode.field(5, decode.int)
  use deleted_at_raw <- decode.field(6, decode.optional(decode.int))
  let tab =
    library_manager_advanced_schema.Tab(
      label: option.Some(label),
      order: option.Some(order),
      view_config: view_config,
      tracks: [],
      identities: library_manager_advanced_schema.ByTabLabel(label:),
    )
  decode.success(#(
    tab,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn trackbucket_with_magic_row_decoder() -> decode.Decoder(
  #(library_manager_advanced_schema.TrackBucket, dsl.MagicFields),
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
    library_manager_advanced_schema.TrackBucket(
      title:,
      artist:,
      matched_tracks: [],
      identities: library_manager_advanced_schema.ByBucketTitleAndArtist(
        title: title_raw,
        artist: artist_raw,
      ),
      relationships: library_manager_advanced_schema.TrackBucketRelationships(
        tags: [],
      ),
    )
  decode.success(#(
    trackbucket,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn tag_with_magic_row_decoder() -> decode.Decoder(
  #(library_manager_advanced_schema.Tag, dsl.MagicFields),
) {
  use label <- decode.field(0, decode.string)
  use emoji <- decode.field(1, decode.string)
  use id <- decode.field(2, decode.int)
  use created_at <- decode.field(3, decode.int)
  use updated_at <- decode.field(4, decode.int)
  use deleted_at_raw <- decode.field(5, decode.optional(decode.int))
  let tag =
    library_manager_advanced_schema.Tag(
      label: option.Some(label),
      emoji: api_help.opt_string_from_db(emoji),
      identities: library_manager_advanced_schema.ByTagLabel(label:),
    )
  decode.success(#(
    tag,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

pub fn importedtrack_with_magic_row_decoder() -> decode.Decoder(
  #(library_manager_advanced_schema.ImportedTrack, dsl.MagicFields),
) {
  use title <- decode.field(0, decode.string)
  use artist <- decode.field(1, decode.string)
  use file_path <- decode.field(2, decode.string)
  use id <- decode.field(3, decode.int)
  use created_at <- decode.field(4, decode.int)
  use updated_at <- decode.field(5, decode.int)
  use deleted_at_raw <- decode.field(6, decode.optional(decode.int))
  let importedtrack =
    library_manager_advanced_schema.ImportedTrack(
      title: option.Some(title),
      artist: option.Some(artist),
      file_path: api_help.opt_string_from_db(file_path),
      tags: [],
      identities: library_manager_advanced_schema.ByTitleAndArtist(
        title:,
        artist:,
      ),
    )
  decode.success(#(
    importedtrack,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
