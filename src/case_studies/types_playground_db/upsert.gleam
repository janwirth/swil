import case_studies/types_playground_db/cmd
import case_studies/types_playground_db/get
import case_studies/types_playground_schema
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/dsl/dsl

/// Update a mytrack by row id (all scalar columns, including natural-key fields).
pub fn update_mytrack_by_id(
  conn: sqlight.Connection,
  id id: Int,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
  name name: option.Option(String),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_mytrack_by_id(conn, id))
  case existing {
    option.None -> Error(not_found_mytrack_id_error("update_mytrack_by_id"))
    option.Some(_) -> {
      case
        cmd.execute_mytrack_cmds(conn, [
          cmd.UpdateMyTrackById(
            id: id,
            added_to_playlist_at: added_to_playlist_at,
            name: name,
          ),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_mytrack_by_id(conn, id))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_mytrack_id_error("update_mytrack_by_id"))
          }
        }
      }
    }
  }
}

fn not_found_mytrack_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "mytrack" <> " not found: " <> op,
    -1,
  )
}

/// Upsert many mytrack rows by the `ByName` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_mytrack_by_name`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_mytrack_by_name(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, option.Option(Timestamp)) ->
      Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error),
) -> Result(
  List(#(types_playground_schema.MyTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(
      name: String,
      added_to_playlist_at: option.Option(Timestamp),
    ) {
      upsert_mytrack_by_name(
        conn,
        name: name,
        added_to_playlist_at: added_to_playlist_at,
      )
    }
    each(item, upsert_row)
  })
}

/// Update a mytrack by the `ByName` identity.
pub fn update_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_mytrack_by_name(conn, name: name))
  case existing {
    option.None -> Error(not_found_mytrack_name_error("update_mytrack_by_name"))
    option.Some(_) -> {
      case
        cmd.execute_mytrack_cmds(conn, [
          cmd.UpdateMyTrackByName(
            name: name,
            added_to_playlist_at: added_to_playlist_at,
          ),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_mytrack_by_name(conn, name: name))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_mytrack_name_error("update_mytrack_by_name"))
          }
        }
      }
    }
  }
}

/// Upsert a mytrack by the `ByName` identity.
pub fn upsert_mytrack_by_name(
  conn: sqlight.Connection,
  name name: String,
  added_to_playlist_at added_to_playlist_at: option.Option(Timestamp),
) -> Result(#(types_playground_schema.MyTrack, dsl.MagicFields), sqlight.Error) {
  case
    cmd.execute_mytrack_cmds(conn, [
      cmd.UpsertMyTrackByName(
        name: name,
        added_to_playlist_at: added_to_playlist_at,
      ),
    ])
  {
    Error(#(_, e)) -> Error(e)
    Ok(Nil) -> {
      use row_opt <- result.try(get.get_mytrack_by_name(conn, name: name))
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

fn not_found_mytrack_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "mytrack" <> " not found: " <> op,
    -1,
  )
}
