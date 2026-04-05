import gleam/list
import gleam/option
import gleam/string
import sqlight
import swil/runtime/api_help
import swil/runtime/cmd_runner

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/runtime/cmd_runner` for batching.
pub type ItemCommand {
  UpsertItemByNameAndAge(name: String, age: Int)
  UpdateItemByNameAndAge(name: String, age: Int)
  PatchItemByNameAndAge(name: String, age: Int)
  DeleteItemByNameAndAge(name: String, age: Int)
  UpdateItemById(id: Int, name: option.Option(String), age: option.Option(Int))
  PatchItemById(id: Int, name: option.Option(String), age: option.Option(Int))
}

const item_upsert_by_name_and_age_sql = "insert into \"item\" (\"name\", \"age\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"name\", \"age\") do update set
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const item_update_by_name_and_age_sql = "update \"item\" set \"updated_at\" = ? where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null;"

const item_delete_by_name_and_age_sql = "update \"item\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null;"

const item_update_by_id_sql = "update \"item\" set \"name\" = ?, \"age\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_item_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(ItemCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, item_variant_tag, plan_item)
}

fn item_variant_tag(cmd cmd: ItemCommand) -> Int {
  case cmd {
    UpsertItemByNameAndAge(..) -> 0
    UpdateItemByNameAndAge(..) -> 1
    PatchItemByNameAndAge(..) -> 2
    DeleteItemByNameAndAge(..) -> 3
    PatchItemById(..) -> 4
    UpdateItemById(..) -> 5
  }
}

fn plan_item(
  cmd cmd: ItemCommand,
  now now: Int,
) -> #(String, List(sqlight.Value)) {
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
    PatchItemByNameAndAge(name:, age:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"item\" set "
        <> set_sql
        <> " where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(name),
            sqlight.int(age),
          ],
        ])
      #(sql, binds)
    }
    DeleteItemByNameAndAge(name:, age:) -> #(item_delete_by_name_and_age_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
      sqlight.int(age),
    ])
    PatchItemById(id:, name:, age:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case name {
        option.None -> #(set_parts, binds)
        option.Some(name_pv) -> #(["\"name\" = ?", ..set_parts], [
          sqlight.text(name_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case age {
        option.None -> #(set_parts, binds)
        option.Some(age_pv) -> #(["\"age\" = ?", ..set_parts], [
          sqlight.int(age_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"item\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
    UpdateItemById(id:, name:, age:) -> #(item_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(name)),
      sqlight.int(api_help.opt_int_for_db(age)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}
