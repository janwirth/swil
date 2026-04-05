import gleam/list
import gleam/option
import gleam/string
import sqlight
import swil/api_help
import swil/cmd_runner

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
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
    PatchFruitByName(name:, color:, price:, quantity:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case color {
        option.None -> #(set_parts, binds)
        option.Some(color_pv) -> #(["\"color\" = ?", ..set_parts], [
          sqlight.text(color_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case price {
        option.None -> #(set_parts, binds)
        option.Some(price_pv) -> #(["\"price\" = ?", ..set_parts], [
          sqlight.float(price_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case quantity {
        option.None -> #(set_parts, binds)
        option.Some(quantity_pv) -> #(["\"quantity\" = ?", ..set_parts], [
          sqlight.int(quantity_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"fruit\" set "
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
    DeleteFruitByName(name:) -> #(fruit_delete_by_name_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(name),
    ])
    PatchFruitById(id:, name:, color:, price:, quantity:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case name {
        option.None -> #(set_parts, binds)
        option.Some(name_pv) -> #(["\"name\" = ?", ..set_parts], [
          sqlight.text(name_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case color {
        option.None -> #(set_parts, binds)
        option.Some(color_pv) -> #(["\"color\" = ?", ..set_parts], [
          sqlight.text(color_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case price {
        option.None -> #(set_parts, binds)
        option.Some(price_pv) -> #(["\"price\" = ?", ..set_parts], [
          sqlight.float(price_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case quantity {
        option.None -> #(set_parts, binds)
        option.Some(quantity_pv) -> #(["\"quantity\" = ?", ..set_parts], [
          sqlight.int(quantity_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"fruit\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
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
