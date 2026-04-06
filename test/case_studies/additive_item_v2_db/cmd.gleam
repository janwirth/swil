import gleam/option
import sqlight
import swil/runtime/api_help
import swil/runtime/cmd_runner
import swil/runtime/patch

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/runtime/cmd_runner` for batching.
pub type ItemCommand {
  UpsertItemByName(
    name: String,
    age: option.Option(Int),
    height: option.Option(Float),
  )
  UpdateItemByName(
    name: String,
    age: option.Option(Int),
    height: option.Option(Float),
  )
  PatchItemByName(
    name: String,
    age: option.Option(Int),
    height: option.Option(Float),
  )
  DeleteItemByName(name: String)
  UpsertItemByNameAndAge(name: String, age: Int, height: option.Option(Float))
  UpdateItemByNameAndAge(name: String, age: Int, height: option.Option(Float))
  PatchItemByNameAndAge(name: String, age: Int, height: option.Option(Float))
  DeleteItemByNameAndAge(name: String, age: Int)
  UpdateItemById(
    id: Int,
    name: option.Option(String),
    age: option.Option(Int),
    height: option.Option(Float),
  )
  PatchItemById(
    id: Int,
    name: option.Option(String),
    age: option.Option(Int),
    height: option.Option(Float),
  )
}

const item_upsert_by_name_sql = "insert into \"item\" (\"name\", \"age\", \"height\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"age\" = excluded.\"age\",
  \"height\" = excluded.\"height\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const item_update_by_name_sql = "update \"item\" set \"age\" = ?, \"height\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

const item_delete_by_name_sql = "update \"item\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

const item_upsert_by_name_and_age_sql = "insert into \"item\" (\"name\", \"age\", \"height\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"name\", \"age\") do update set
  \"height\" = excluded.\"height\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const item_update_by_name_and_age_sql = "update \"item\" set \"height\" = ?, \"updated_at\" = ? where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null;"

const item_delete_by_name_and_age_sql = "update \"item\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null;"

const item_update_by_id_sql = "update \"item\" set \"name\" = ?, \"age\" = ?, \"height\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_item_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(ItemCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, item_variant_tag, plan_item)
}

fn item_variant_tag(cmd cmd: ItemCommand) -> Int {
  case cmd {
    UpsertItemByName(..) -> 0
    UpdateItemByName(..) -> 1
    PatchItemByName(..) -> 2
    DeleteItemByName(..) -> 3
    UpsertItemByNameAndAge(..) -> 4
    UpdateItemByNameAndAge(..) -> 5
    PatchItemByNameAndAge(..) -> 6
    DeleteItemByNameAndAge(..) -> 7
    PatchItemById(..) -> 8
    UpdateItemById(..) -> 9
  }
}

fn plan_item(
  cmd cmd: ItemCommand,
  now now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertItemByName(name:, age:, height:) -> #(item_upsert_by_name_sql, [
      sqlight.text(name),
      sqlight.int(api_help.opt_int_for_db(age)),
      sqlight.float(api_help.opt_float_for_db(height)),
      sqlight.int(now),
      sqlight.int(now),
    ])
    UpdateItemByName(name:, age:, height:) -> #(item_update_by_name_sql, [
      sqlight.int(api_help.opt_int_for_db(age)),
      sqlight.float(api_help.opt_float_for_db(height)),
      sqlight.int(now),
      sqlight.text(name),
    ])
    PatchItemByName(name:, age:, height:) ->
      patch.new()
      |> patch.add_int("age", age)
      |> patch.add_float("height", height)
      |> patch.always_int("updated_at", now)
      |> patch.build("item", "\"name\" = ? and \"deleted_at\" is null;", [
        sqlight.text(name),
      ])
    DeleteItemByName(name:) -> #(item_delete_by_name_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
    ])
    UpsertItemByNameAndAge(name:, age:, height:) -> #(
      item_upsert_by_name_and_age_sql,
      [
        sqlight.text(name),
        sqlight.int(age),
        sqlight.float(api_help.opt_float_for_db(height)),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateItemByNameAndAge(name:, age:, height:) -> #(
      item_update_by_name_and_age_sql,
      [
        sqlight.float(api_help.opt_float_for_db(height)),
        sqlight.int(now),
        sqlight.text(name),
        sqlight.int(age),
      ],
    )
    PatchItemByNameAndAge(name:, age:, height:) ->
      patch.new()
      |> patch.add_float("height", height)
      |> patch.always_int("updated_at", now)
      |> patch.build(
        "item",
        "\"name\" = ? and \"age\" = ? and \"deleted_at\" is null;",
        [sqlight.text(name), sqlight.int(age)],
      )
    DeleteItemByNameAndAge(name:, age:) -> #(item_delete_by_name_and_age_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
      sqlight.int(age),
    ])
    PatchItemById(id:, name:, age:, height:) ->
      patch.new()
      |> patch.add_text("name", name)
      |> patch.add_int("age", age)
      |> patch.add_float("height", height)
      |> patch.always_int("updated_at", now)
      |> patch.build("item", "\"id\" = ? and \"deleted_at\" is null;", [
        sqlight.int(id),
      ])
    UpdateItemById(id:, name:, age:, height:) -> #(item_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(name)),
      sqlight.int(api_help.opt_int_for_db(age)),
      sqlight.float(api_help.opt_float_for_db(height)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}
