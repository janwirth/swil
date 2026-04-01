import case_studies/imported_track_evolution_v1_schema
import gleam/dynamic/decode
import gleam/option
import swil/api_help
import swil/dsl/dsl

pub fn importedtrack_with_magic_row_decoder() -> decode.Decoder(
  #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
) {
  use title <- decode.field(0, decode.string)
  use artist <- decode.field(1, decode.string)
  use service <- decode.field(2, decode.string)
  use source_id <- decode.field(3, decode.string)
  use external_source_url <- decode.field(4, decode.string)
  use id <- decode.field(5, decode.int)
  use created_at <- decode.field(6, decode.int)
  use updated_at <- decode.field(7, decode.int)
  use deleted_at_raw <- decode.field(8, decode.optional(decode.int))
  let importedtrack =
    imported_track_evolution_v1_schema.ImportedTrack(
      title: api_help.opt_string_from_db(title),
      artist: api_help.opt_string_from_db(artist),
      service: option.Some(service),
      source_id: option.Some(source_id),
      external_source_url: api_help.opt_string_from_db(external_source_url),
      identities: imported_track_evolution_v1_schema.ByServiceAndSourceId(
        service:,
        source_id:,
      ),
    )
  decode.success(#(
    importedtrack,
    api_help.magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}
