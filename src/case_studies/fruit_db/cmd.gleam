/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
import gleam/option
import sqlight
import swil/api_help
import swil/cmd_runner

/// Upsert/update payload for `ByName` identity on `Fruit`.
pub type FruitByName {
  FruitByName(
    name: String,
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
}

pub type FruitCommand {
  /// Upsert by `ByName` identity.
  UpsertFruitByName(
    name: String,
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
  /// Update by `ByName` identity.
  UpdateFruitByName(
    name: String,
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
  )
  /// Soft-delete by `ByName` identity.
  DeleteFruitByName(name: String)
  /// Update all scalar columns by row `id`.
  UpdateFruitById(
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

fn plan_fruit(cmd: FruitCommand, now: Int) -> #(String, List(sqlight.Value)) {
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
    DeleteFruitByName(name:) -> #(fruit_delete_by_name_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
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

fn fruit_variant_tag(cmd: FruitCommand) -> Int {
  case cmd {
    UpsertFruitByName(..) -> 0
    UpdateFruitByName(..) -> 1
    DeleteFruitByName(..) -> 2
    UpdateFruitById(..) -> 3
  }
}

pub fn execute_fruit_cmds(
  conn: sqlight.Connection,
  commands: List(FruitCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, fruit_variant_tag, plan_fruit)
}
