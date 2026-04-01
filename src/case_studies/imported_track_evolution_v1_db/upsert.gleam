import case_studies/imported_track_evolution_v1_db/row
import case_studies/imported_track_evolution_v1_schema
import gleam/list
import gleam/option
import gleam/result
import sqlight
import swil/api_help
import swil/dsl/dsl

const update_importedtrack_by_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"service\" = ?, \"source_id\" = ?, \"external_source_url\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"service\", \"source_id\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const update_importedtrack_by_service_and_source_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"external_source_url\" = ?, \"updated_at\" = ? where \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"service\", \"source_id\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const upsert_importedtrack_by_service_and_source_id_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"service\", \"source_id\", \"external_source_url\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, ?, ?, null)
on conflict(\"service\", \"source_id\") do update set
  \"title\" = excluded.\"title\",
  \"artist\" = excluded.\"artist\",
  \"external_source_url\" = excluded.\"external_source_url\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"title\", \"artist\", \"service\", \"source_id\", \"external_source_url\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

/// Update a importedtrack by row id (all scalar columns, including natural-key fields).
pub fn update_importedtrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
  title title: option.Option(String),
  artist artist: option.Option(String),
  service service: option.Option(String),
  source_id source_id: option.Option(String),
  external_source_url external_source_url: option.Option(String),
) -> Result(
  #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  let db_title = api_help.opt_text_for_db(title)
  let db_artist = api_help.opt_text_for_db(artist)
  let db_service = api_help.opt_text_for_db(service)
  let db_source_id = api_help.opt_text_for_db(source_id)
  let db_external_source_url = api_help.opt_text_for_db(external_source_url)
  use rows <- result.try(sqlight.query(
    update_importedtrack_by_id_sql,
    on: conn,
    with: [
      sqlight.text(db_title),
      sqlight.text(db_artist),
      sqlight.text(db_service),
      sqlight.text(db_source_id),
      sqlight.text(db_external_source_url),
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

/// Upsert many importedtrack rows by the `ByServiceAndSourceId` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_importedtrack_by_service_and_source_id`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(
      String,
      String,
      option.Option(String),
      option.Option(String),
      option.Option(String),
    ) ->
      Result(
        #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
        sqlight.Error,
      ),
  ) ->
    Result(
      #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
      sqlight.Error,
    ),
) -> Result(
  List(#(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(
      service: String,
      source_id: String,
      title: option.Option(String),
      artist: option.Option(String),
      external_source_url: option.Option(String),
    ) {
      upsert_importedtrack_by_service_and_source_id(
        conn,
        service: service,
        source_id: source_id,
        title: title,
        artist: artist,
        external_source_url: external_source_url,
      )
    }
    each(item, upsert_row)
  })
}

/// Update a importedtrack by the `ByServiceAndSourceId` identity.
pub fn update_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
  title title: option.Option(String),
  artist artist: option.Option(String),
  external_source_url external_source_url: option.Option(String),
) -> Result(
  #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  let db_title = api_help.opt_text_for_db(title)
  let db_artist = api_help.opt_text_for_db(artist)
  let db_external_source_url = api_help.opt_text_for_db(external_source_url)
  use rows <- result.try(sqlight.query(
    update_importedtrack_by_service_and_source_id_sql,
    on: conn,
    with: [
      sqlight.text(db_title),
      sqlight.text(db_artist),
      sqlight.text(db_external_source_url),
      sqlight.int(now),
      sqlight.text(service),
      sqlight.text(source_id),
    ],
    expecting: row.importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [r, ..] -> Ok(r)
    [] ->
      Error(not_found_importedtrack_service_and_source_id_error(
        "update_importedtrack_by_service_and_source_id",
      ))
  }
}

/// Upsert a importedtrack by the `ByServiceAndSourceId` identity.
pub fn upsert_importedtrack_by_service_and_source_id(
  conn: sqlight.Connection,
  service service: String,
  source_id source_id: String,
  title title: option.Option(String),
  artist artist: option.Option(String),
  external_source_url external_source_url: option.Option(String),
) -> Result(
  #(imported_track_evolution_v1_schema.ImportedTrack, dsl.MagicFields),
  sqlight.Error,
) {
  let now = api_help.unix_seconds_now()
  let db_title = api_help.opt_text_for_db(title)
  let db_artist = api_help.opt_text_for_db(artist)
  let db_external_source_url = api_help.opt_text_for_db(external_source_url)
  use rows <- result.try(sqlight.query(
    upsert_importedtrack_by_service_and_source_id_sql,
    on: conn,
    with: [
      sqlight.text(db_title),
      sqlight.text(db_artist),
      sqlight.text(service),
      sqlight.text(source_id),
      sqlight.text(db_external_source_url),
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

fn not_found_importedtrack_service_and_source_id_error(
  op: String,
) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}
