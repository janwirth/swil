import case_studies/imported_track_evolution_v1_db/cmd
import case_studies/imported_track_evolution_v1_db/get
import case_studies/imported_track_evolution_v1_schema
import gleam/list
import gleam/option
import gleam/result
import sqlight
import swil/dsl/dsl

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
  use existing <- result.try(get.get_importedtrack_by_id(conn, id))
  case existing {
    option.None ->
      Error(not_found_importedtrack_id_error("update_importedtrack_by_id"))
    option.Some(_) -> {
      case
        cmd.execute_importedtrack_cmds(conn, [
          cmd.UpdateImportedTrackById(
            id: id,
            title: title,
            artist: artist,
            service: service,
            source_id: source_id,
            external_source_url: external_source_url,
          ),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_importedtrack_by_id(conn, id))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_importedtrack_id_error(
                "update_importedtrack_by_id",
              ))
          }
        }
      }
    }
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
  use existing <- result.try(get.get_importedtrack_by_service_and_source_id(
    conn,
    service: service,
    source_id: source_id,
  ))
  case existing {
    option.None ->
      Error(not_found_importedtrack_service_and_source_id_error(
        "update_importedtrack_by_service_and_source_id",
      ))
    option.Some(_) -> {
      case
        cmd.execute_importedtrack_cmds(conn, [
          cmd.UpdateImportedTrackByServiceAndSourceId(
            service: service,
            source_id: source_id,
            title: title,
            artist: artist,
            external_source_url: external_source_url,
          ),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(
            get.get_importedtrack_by_service_and_source_id(
              conn,
              service: service,
              source_id: source_id,
            ),
          )
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_importedtrack_service_and_source_id_error(
                "update_importedtrack_by_service_and_source_id",
              ))
          }
        }
      }
    }
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
  case
    cmd.execute_importedtrack_cmds(conn, [
      cmd.UpsertImportedTrackByServiceAndSourceId(
        service: service,
        source_id: source_id,
        title: title,
        artist: artist,
        external_source_url: external_source_url,
      ),
    ])
  {
    Error(#(_, e)) -> Error(e)
    Ok(Nil) -> {
      use row_opt <- result.try(get.get_importedtrack_by_service_and_source_id(
        conn,
        service: service,
        source_id: source_id,
      ))
      case row_opt {
        option.Some(r) -> Ok(r)
        option.None ->
          Error(sqlight.SqlightError(
            sqlight.GenericError,
            "upsert returned no row",
            -1,
          ))
      }
    }
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
