import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/api_help
import swil/cmd_runner

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
pub type MyTrackCommand {
  UpsertMyTrackByName(
    name: String,
    added_to_playlist_at: option.Option(Timestamp),
  )
  UpdateMyTrackByName(
    name: String,
    added_to_playlist_at: option.Option(Timestamp),
  )
  PatchMyTrackByName(
    name: String,
    added_to_playlist_at: option.Option(Timestamp),
  )
  DeleteMyTrackByName(name: String)
  UpdateMyTrackById(
    id: Int,
    added_to_playlist_at: option.Option(Timestamp),
    name: option.Option(String),
  )
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

pub fn execute_mytrack_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(MyTrackCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, mytrack_variant_tag, plan_mytrack)
}

fn mytrack_variant_tag(cmd cmd: MyTrackCommand) -> Int {
  case cmd {
    UpsertMyTrackByName(..) -> 0
    UpdateMyTrackByName(..) -> 1
    PatchMyTrackByName(..) -> 2
    DeleteMyTrackByName(..) -> 3
    PatchMyTrackById(..) -> 4
    UpdateMyTrackById(..) -> 5
  }
}

fn plan_mytrack(
  cmd cmd: MyTrackCommand,
  now now: Int,
) -> #(String, List(sqlight.Value)) {
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
