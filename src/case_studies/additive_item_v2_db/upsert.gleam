import case_studies/additive_item_v2_db/cmd
import case_studies/additive_item_v2_db/get
import case_studies/additive_item_v2_schema
import gleam/list
import gleam/option
import gleam/result
import sqlight
import swil/dsl/dsl

/// Update a item by row id (all scalar columns, including natural-key fields).
pub fn update_item_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  age age: option.Option(Int),
  height height: option.Option(Float),
) -> Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_item_by_id(conn, id))
  case existing {
    option.None -> Error(not_found_item_id_error("update_item_by_id"))
    option.Some(_) -> {
      case
        cmd.execute_item_cmds(conn, [
          cmd.UpdateItemById(id: id, name: name, age: age, height: height),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_item_by_id(conn, id))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None -> Error(not_found_item_id_error("update_item_by_id"))
          }
        }
      }
    }
  }
}

fn not_found_item_id_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "item" <> " not found: " <> op, -1)
}

/// Upsert many item rows by the `ByNameAndAge` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_item_by_name_and_age`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_item_by_name_and_age(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, Int, option.Option(Float)) ->
      Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error),
) -> Result(
  List(#(additive_item_v2_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(name: String, age: Int, height: option.Option(Float)) {
      upsert_item_by_name_and_age(conn, name: name, age: age, height: height)
    }
    each(item, upsert_row)
  })
}

/// Update a item by the `ByNameAndAge` identity.
pub fn update_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
  height height: option.Option(Float),
) -> Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_item_by_name_and_age(
    conn,
    name: name,
    age: age,
  ))
  case existing {
    option.None ->
      Error(not_found_item_name_and_age_error("update_item_by_name_and_age"))
    option.Some(_) -> {
      case
        cmd.execute_item_cmds(conn, [
          cmd.UpdateItemByNameAndAge(name: name, age: age, height: height),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_item_by_name_and_age(
            conn,
            name: name,
            age: age,
          ))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_item_name_and_age_error(
                "update_item_by_name_and_age",
              ))
          }
        }
      }
    }
  }
}

/// Upsert a item by the `ByNameAndAge` identity.
pub fn upsert_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
  height height: option.Option(Float),
) -> Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error) {
  case
    cmd.execute_item_cmds(conn, [
      cmd.UpsertItemByNameAndAge(name: name, age: age, height: height),
    ])
  {
    Error(#(_, e)) -> Error(e)
    Ok(Nil) -> {
      use row_opt <- result.try(get.get_item_by_name_and_age(
        conn,
        name: name,
        age: age,
      ))
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

fn not_found_item_name_and_age_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "item" <> " not found: " <> op, -1)
}

/// Upsert many item rows by the `ByName` identity (one SQL upsert per item).
/// `conn` is only an argument here — `each` gets `item` and `upsert_row` (same labelled fields as `upsert_item_by_name`, but no connection parameter; the outer `conn` is used automatically).
pub fn upsert_many_item_by_name(
  conn: sqlight.Connection,
  items items: List(a),
  each each: fn(
    a,
    fn(String, option.Option(Int), option.Option(Float)) ->
      Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error),
  ) ->
    Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error),
) -> Result(
  List(#(additive_item_v2_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(items, fn(item) {
    let upsert_row = fn(
      name: String,
      age: option.Option(Int),
      height: option.Option(Float),
    ) {
      upsert_item_by_name(conn, name: name, age: age, height: height)
    }
    each(item, upsert_row)
  })
}

/// Update a item by the `ByName` identity.
pub fn update_item_by_name(
  conn: sqlight.Connection,
  name name: String,
  age age: option.Option(Int),
  height height: option.Option(Float),
) -> Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error) {
  use existing <- result.try(get.get_item_by_name(conn, name: name))
  case existing {
    option.None -> Error(not_found_item_name_error("update_item_by_name"))
    option.Some(_) -> {
      case
        cmd.execute_item_cmds(conn, [
          cmd.UpdateItemByName(name: name, age: age, height: height),
        ])
      {
        Error(#(_, e)) -> Error(e)
        Ok(Nil) -> {
          use row_opt <- result.try(get.get_item_by_name(conn, name: name))
          case row_opt {
            option.Some(r) -> Ok(r)
            option.None ->
              Error(not_found_item_name_error("update_item_by_name"))
          }
        }
      }
    }
  }
}

/// Upsert a item by the `ByName` identity.
pub fn upsert_item_by_name(
  conn: sqlight.Connection,
  name name: String,
  age age: option.Option(Int),
  height height: option.Option(Float),
) -> Result(#(additive_item_v2_schema.Item, dsl.MagicFields), sqlight.Error) {
  case
    cmd.execute_item_cmds(conn, [
      cmd.UpsertItemByName(name: name, age: age, height: height),
    ])
  {
    Error(#(_, e)) -> Error(e)
    Ok(Nil) -> {
      use row_opt <- result.try(get.get_item_by_name(conn, name: name))
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

fn not_found_item_name_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "item" <> " not found: " <> op, -1)
}
