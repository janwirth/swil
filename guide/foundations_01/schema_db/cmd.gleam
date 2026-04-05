/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/runtime/cmd_runner` for batching.
import gleam/option
import sqlight
import swil/runtime/api_help
import swil/runtime/cmd_runner

pub type Guide01ItemCommand {
  /// Upsert by `ByName` identity.
  UpsertGuide01ItemByName(name: String, note: option.Option(String))
  /// Update by `ByName` identity.
  UpdateGuide01ItemByName(name: String, note: option.Option(String))
  /// Soft-delete by `ByName` identity.
  DeleteGuide01ItemByName(name: String)
  /// Update all scalar columns by row `id`.
  UpdateGuide01ItemById(
    id: Int,
    name: option.Option(String),
    note: option.Option(String),
  )
}

const guide01item_upsert_by_name_sql = "insert into \"guide01item\" (\"name\", \"note\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"note\" = excluded.\"note\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const guide01item_update_by_name_sql = "update \"guide01item\" set \"note\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

const guide01item_delete_by_name_sql = "update \"guide01item\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

const guide01item_update_by_id_sql = "update \"guide01item\" set \"name\" = ?, \"note\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

fn plan_guide01item(
  cmd: Guide01ItemCommand,
  now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertGuide01ItemByName(name:, note:) -> #(guide01item_upsert_by_name_sql, [
      sqlight.text(name),
      sqlight.text(api_help.opt_text_for_db(note)),
      sqlight.int(now),
      sqlight.int(now),
    ])
    UpdateGuide01ItemByName(name:, note:) -> #(guide01item_update_by_name_sql, [
      sqlight.text(api_help.opt_text_for_db(note)),
      sqlight.int(now),
      sqlight.text(name),
    ])
    DeleteGuide01ItemByName(name:) -> #(guide01item_delete_by_name_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
    ])
    UpdateGuide01ItemById(id:, name:, note:) -> #(guide01item_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(name)),
      sqlight.text(api_help.opt_text_for_db(note)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

fn guide01item_variant_tag(cmd: Guide01ItemCommand) -> Int {
  case cmd {
    UpsertGuide01ItemByName(..) -> 0
    UpdateGuide01ItemByName(..) -> 1
    DeleteGuide01ItemByName(..) -> 2
    UpdateGuide01ItemById(..) -> 3
  }
}

pub fn execute_guide01item_cmds(
  conn: sqlight.Connection,
  commands: List(Guide01ItemCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, guide01item_variant_tag, plan_guide01item)
}
