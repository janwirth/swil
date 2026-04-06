import gleam/option
import sqlight
import swil/runtime/api_help
import swil/runtime/cmd_runner
import swil/runtime/patch

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/runtime/cmd_runner` for batching.
pub type FruitCommand {
  UpsertFruitByName(
    name: String,
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
  UpdateFruitByName(
    name: String,
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
  PatchFruitByName(
    name: String,
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
  DeleteFruitByName(name: String)
  UpdateFruitById(
    id: Int,
    name: option.Option(String),
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
  PatchFruitById(
    id: Int,
    name: option.Option(String),
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
}

const fruit_upsert_by_name_sql = "insert into \"fruit\" (\"name\", \"color\", \"price\", \"quantity\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"color\" = excluded.\"color\",
  \"price\" = excluded.\"price\",
  \"quantity\" = excluded.\"quantity\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const fruit_update_by_name_sql = "update \"fruit\" set \"color\" = ?, \"price\" = ?, \"quantity\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

const fruit_delete_by_name_sql = "update \"fruit\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

const fruit_update_by_id_sql = "update \"fruit\" set \"name\" = ?, \"color\" = ?, \"price\" = ?, \"quantity\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_fruit_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(FruitCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, fruit_variant_tag, plan_fruit)
}

fn fruit_variant_tag(cmd cmd: FruitCommand) -> Int {
  case cmd {
    UpsertFruitByName(..) -> 0
    UpdateFruitByName(..) -> 1
    PatchFruitByName(..) -> 2
    DeleteFruitByName(..) -> 3
    PatchFruitById(..) -> 4
    UpdateFruitById(..) -> 5
  }
}

fn plan_fruit(
  cmd cmd: FruitCommand,
  now now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertFruitByName(name:, color:, price:, quantity:) -> #(
      fruit_upsert_by_name_sql,
      [
        sqlight.text(name),
        sqlight.text(api_help.opt_text_for_db(color)),
        sqlight.float(api_help.opt_float_for_db(price)),
        sqlight.int(api_help.opt_int_for_db(quantity)),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateFruitByName(name:, color:, price:, quantity:) -> #(
      fruit_update_by_name_sql,
      [
        sqlight.text(api_help.opt_text_for_db(color)),
        sqlight.float(api_help.opt_float_for_db(price)),
        sqlight.int(api_help.opt_int_for_db(quantity)),
        sqlight.int(now),
        sqlight.text(name),
      ],
    )
    PatchFruitByName(name:, color:, price:, quantity:) ->
      patch.new()
      |> patch.add_text("color", color)
      |> patch.add_float("price", price)
      |> patch.add_int("quantity", quantity)
      |> patch.always_int("updated_at", now)
      |> patch.build("fruit", "\"name\" = ? and \"deleted_at\" is null;", [
        sqlight.text(name),
      ])
    DeleteFruitByName(name:) -> #(fruit_delete_by_name_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
    ])
    PatchFruitById(id:, name:, color:, price:, quantity:) ->
      patch.new()
      |> patch.add_text("name", name)
      |> patch.add_text("color", color)
      |> patch.add_float("price", price)
      |> patch.add_int("quantity", quantity)
      |> patch.always_int("updated_at", now)
      |> patch.build("fruit", "\"id\" = ? and \"deleted_at\" is null;", [
        sqlight.int(id),
      ])
    UpdateFruitById(id:, name:, color:, price:, quantity:) -> #(
      fruit_update_by_id_sql,
      [
        sqlight.text(api_help.opt_text_for_db(name)),
        sqlight.text(api_help.opt_text_for_db(color)),
        sqlight.float(api_help.opt_float_for_db(price)),
        sqlight.int(api_help.opt_int_for_db(quantity)),
        sqlight.int(now),
        sqlight.int(id),
      ],
    )
  }
}
