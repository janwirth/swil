import gleam/option
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/runtime/api_help
import swil/runtime/cmd_runner
import swil/runtime/patch

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/runtime/cmd_runner` for batching.
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
    PatchMyTrackByName(name:, added_to_playlist_at:) ->
      patch.new()
      |> patch.add_int(
        "added_to_playlist_at",
        option.map(added_to_playlist_at, fn(t) {
          let #(s, _) = timestamp.to_unix_seconds_and_nanoseconds(t)
          s
        }),
      )
      |> patch.always_int("updated_at", now)
      |> patch.build("mytrack", "\"name\" = ? and \"deleted_at\" is null;", [
        sqlight.text(name),
      ])
    DeleteMyTrackByName(name:) -> #(mytrack_delete_by_name_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
    ])
    PatchMyTrackById(id:, added_to_playlist_at:, name:) ->
      patch.new()
      |> patch.add_int(
        "added_to_playlist_at",
        option.map(added_to_playlist_at, fn(t) {
          let #(s, _) = timestamp.to_unix_seconds_and_nanoseconds(t)
          s
        }),
      )
      |> patch.add_text("name", name)
      |> patch.always_int("updated_at", now)
      |> patch.build("mytrack", "\"id\" = ? and \"deleted_at\" is null;", [
        sqlight.int(id),
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
