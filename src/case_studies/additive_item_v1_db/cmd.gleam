/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
import gleam/option
import sqlight
import swil/api_help
import swil/cmd_runner

/// Upsert/update payload for `ByNameAndAge` identity on `Item`.
pub type ItemByNameAndAge {
  ItemByNameAndAge(name: String, age: Int)
}

pub type ItemCommand {
  /// Upsert by `ByNameAndAge` identity.
  UpsertItemByNameAndAge(name: String, age: Int)
  /// Update by `ByNameAndAge` identity.
  UpdateItemByNameAndAge(name: String, age: Int)
  /// Soft-delete by `ByNameAndAge` identity.
  DeleteItemByNameAndAge(name: String, age: Int)
  /// Update all scalar columns by row `id`.
  UpdateItemById(id: Int, name: option.Option(String), age: option.Option(Int))
}

const item_upsert_by_name_and_age_sql = "insert into \"item\" (\"name\", \"age\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"name\", \"age\") do update set
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const item_update_by_name_and_age_sql = "update \"item\" set \"updated_at\" = ? where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null;"

const item_delete_by_name_and_age_sql = "update \"item\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null;"

const item_update_by_id_sql = "update \"item\" set \"name\" = ?, \"age\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

fn plan_item(cmd: ItemCommand, now: Int) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertItemByNameAndAge(name:, age:) -> #(item_upsert_by_name_and_age_sql, [
      sqlight.text(name),
      sqlight.int(age),
      sqlight.int(now),
      sqlight.int(now),
    ])
    UpdateItemByNameAndAge(name:, age:) -> #(item_update_by_name_and_age_sql, [
      sqlight.int(now),
      sqlight.text(name),
      sqlight.int(age),
    ])
    DeleteItemByNameAndAge(name:, age:) -> #(item_delete_by_name_and_age_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
      sqlight.int(age),
    ])
    UpdateItemById(id:, name:, age:) -> #(item_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(name)),
      sqlight.int(api_help.opt_int_for_db(age)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

fn item_variant_tag(cmd: ItemCommand) -> Int {
  case cmd {
    UpsertItemByNameAndAge(..) -> 0
    UpdateItemByNameAndAge(..) -> 1
    DeleteItemByNameAndAge(..) -> 2
    UpdateItemById(..) -> 3
  }
}

pub fn execute_item_cmds(
  conn: sqlight.Connection,
  commands: List(ItemCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, item_variant_tag, plan_item)
}
