/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/api_help
import swil/cmd_runner

/// Upsert/update payload for `ByName` identity on `MyTrack`.
pub type MyTrackByName {
  MyTrackByName(name: String, added_to_playlist_at: option.Option(Timestamp))
}

pub type MyTrackCommand {
  /// Upsert by `ByName` identity.
  UpsertMyTrackByName(
    name: String,
    added_to_playlist_at: option.Option(Timestamp),
  )
  /// Update by `ByName` identity.
  UpdateMyTrackByName(
    name: String,
    added_to_playlist_at: option.Option(Timestamp),
  )
  /// Soft-delete by `ByName` identity.
  DeleteMyTrackByName(name: String)
  /// Update all scalar columns by row `id`.
  UpdateMyTrackById(
    id: Int,
    added_to_playlist_at: option.Option(Timestamp),
    name: option.Option(String),
  )
}

const mytrack_upsert_by_name_sql = "insert into \"mytrack\" (\"added_to_playlist_at\", \"name\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"added_to_playlist_at\" = excluded.\"added_to_playlist_at\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const mytrack_update_by_name_sql = "update \"mytrack\" set \"added_to_playlist_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

const mytrack_delete_by_name_sql = "update \"mytrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

const mytrack_update_by_id_sql = "update \"mytrack\" set \"added_to_playlist_at\" = ?, \"name\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

fn plan_mytrack(cmd: MyTrackCommand, now: Int) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertMyTrackByName(name:, added_to_playlist_at:) -> #(
      mytrack_upsert_by_name_sql,
      [
        sqlight.int(api_help.opt_timestamp_for_db(added_to_playlist_at)),
        sqlight.text(name),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateMyTrackByName(name:, added_to_playlist_at:) -> #(
      mytrack_update_by_name_sql,
      [
        sqlight.int(api_help.opt_timestamp_for_db(added_to_playlist_at)),
        sqlight.int(now),
        sqlight.text(name),
      ],
    )
    DeleteMyTrackByName(name:) -> #(mytrack_delete_by_name_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
    ])
    UpdateMyTrackById(id:, added_to_playlist_at:, name:) -> #(
      mytrack_update_by_id_sql,
      [
        sqlight.int(api_help.opt_timestamp_for_db(added_to_playlist_at)),
        sqlight.text(api_help.opt_text_for_db(name)),
        sqlight.int(now),
        sqlight.int(id),
      ],
    )
  }
}

fn mytrack_variant_tag(cmd: MyTrackCommand) -> Int {
  case cmd {
    UpsertMyTrackByName(..) -> 0
    UpdateMyTrackByName(..) -> 1
    DeleteMyTrackByName(..) -> 2
    UpdateMyTrackById(..) -> 3
  }
}

pub fn execute_mytrack_cmds(
  conn: sqlight.Connection,
  commands: List(MyTrackCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, mytrack_variant_tag, plan_mytrack)
}
