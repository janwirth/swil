import case_studies/fruit_db/cmd
import case_studies/fruit_db/get
import case_studies/fruit_schema
import gleam/list
import gleam/option
import gleam/result
import sqlight
import swil/dsl/dsl

/// Update a fruit by row id (all scalar columns, including natural-key fields).
pub fn update_fruit_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_fruit_by_id(conn, id))
  case existing {
    option.None -> Error(not_found_fruit_id_error("update_fruit_by_id"))
    option.Some(_) -> {
      case
        cmd.execute_fruit_cmds(conn, [
          cmd.UpdateFruitById(
            id: id,
            name: name,
            color: color,
            price: price,
            quantity: quantity,
          ),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_fruit_by_id(conn, id))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None -> Error(not_found_fruit_id_error("update_fruit_by_id"))
          }
        }
      }
    }
  }
}

fn not_found_fruit_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "fruit" <> " not found: " <> op,
    -1,
  )
}

/// Upsert many fruit rows by the `ByName` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_fruit_by_name`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_fruit_by_name(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, option.Option(String), option.Option(Float), option.Option(Int)) ->
      Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error),
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(
      name: String,
      color: option.Option(String),
      price: option.Option(Float),
      quantity: option.Option(Int),
    ) {
      upsert_fruit_by_name(
        conn,
        name: name,
        color: color,
        price: price,
        quantity: quantity,
      )
    }
    each(item, upsert_row)
  })
}

/// Update a fruit by the `ByName` identity.
pub fn update_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_fruit_by_name(conn, name: name))
  case existing {
    option.None -> Error(not_found_fruit_name_error("update_fruit_by_name"))
    option.Some(_) -> {
      case
        cmd.execute_fruit_cmds(conn, [
          cmd.UpdateFruitByName(
            name: name,
            color: color,
            price: price,
            quantity: quantity,
          ),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_fruit_by_name(conn, name: name))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_fruit_name_error("update_fruit_by_name"))
          }
        }
      }
    }
  }
}

/// Upsert a fruit by the `ByName` identity.
pub fn upsert_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
  color color: option.Option(String),
  price price: option.Option(Float),
  quantity quantity: option.Option(Int),
) -> Result(#(fruit_schema.Fruit, dsl.MagicFields), sqlight.Error) {
  case
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: name,
        color: color,
        price: price,
        quantity: quantity,
      ),
    ])
  {
    Error(#(_, e)) -> Error(e)
    Ok(Nil) -> {
      use row_opt <- result.try(get.get_fruit_by_name(conn, name: name))
      case row_opt {
        option.Some(r) -> Ok(r)
        option.None ->
          Error(sqlight.SqlightError(
            sqlight.GenericError,
            "upsert returned no row",
            -1,
          ))
      }
    }
  }
}

fn not_found_fruit_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "fruit" <> " not found: " <> op,
    -1,
  )
}
