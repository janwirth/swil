/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/api_help
import swil/cmd_runner

pub type MyTrackCommand {
  /// Upsert by `ByName` identity.
  UpsertMyTrackByName(
    name: String,
    added_to_playlist_at: option.Option(Timestamp),
  )
  /// Update by `ByName` identity (every non-id column is written; `option.None` uses sentinel / empty DB encoding).
  UpdateMyTrackByName(
    name: String,
    added_to_playlist_at: option.Option(Timestamp),
  )
  /// Partial update by `ByName` (`option.None` leaves that column unchanged in SQL).
  PatchMyTrackByName(
    name: String,
    added_to_playlist_at: option.Option(Timestamp),
  )
  /// Soft-delete by `ByName` identity.
  DeleteMyTrackByName(name: String)
  /// Update all scalar columns by row `id` (same sentinel rules as identity `Update`).
  UpdateMyTrackById(
    id: Int,
    added_to_playlist_at: option.Option(Timestamp),
    name: option.Option(String),
  )
  /// Partial update by row `id` (`option.None` leaves that column unchanged).
  PatchMyTrackById(
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
    PatchMyTrackByName(name:, added_to_playlist_at:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case added_to_playlist_at {
        option.None -> #(set_parts, binds)
        option.Some(added_to_playlist_at_pv) -> #(
          ["\"added_to_playlist_at\" = ?", ..set_parts],
          [
            sqlight.int({
              let #(s, _) =
                timestamp.to_unix_seconds_and_nanoseconds(
                  added_to_playlist_at_pv,
                )
              s
            }),
            ..binds
          ],
        )
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"mytrack\" set "
        <> set_sql
        <> " where \"name\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(name),
          ],
        ])
      #(sql, binds)
    }
    DeleteMyTrackByName(name:) -> #(mytrack_delete_by_name_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
    ])
    PatchMyTrackById(id:, added_to_playlist_at:, name:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case added_to_playlist_at {
        option.None -> #(set_parts, binds)
        option.Some(added_to_playlist_at_pv) -> #(
          ["\"added_to_playlist_at\" = ?", ..set_parts],
          [
            sqlight.int({
              let #(s, _) =
                timestamp.to_unix_seconds_and_nanoseconds(
                  added_to_playlist_at_pv,
                )
              s
            }),
            ..binds
          ],
        )
      }
      let #(set_parts, binds) = case name {
        option.None -> #(set_parts, binds)
        option.Some(name_pv) -> #(["\"name\" = ?", ..set_parts], [
          sqlight.text(name_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"mytrack\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
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
    PatchMyTrackByName(..) -> 2
    DeleteMyTrackByName(..) -> 3
    PatchMyTrackById(..) -> 4
    UpdateMyTrackById(..) -> 5
  }
}

pub fn execute_mytrack_cmds(
  conn: sqlight.Connection,
  commands: List(MyTrackCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, mytrack_variant_tag, plan_mytrack)
}
