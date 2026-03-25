import case_studies/fruit_schema.{type Fruit, Fruit, ByName}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import sqlight
import case_studies/fruit_db/migration

// --- SQL (fruit table shape matches `example_migration_fruit` / pragma migrations) ---
//
// insert into fruit (name, color, price, quantity, created_at, updated_at, deleted_at)
//   values (?, ?, ?, ?, ?, ?, null)
//   on conflict(name) do update set
//     color = excluded.color,
//     price = excluded.price,
//     quantity = excluded.quantity,
//     updated_at = excluded.updated_at,
//     deleted_at = null;
//
// select name, color, price, quantity from fruit
//   where name = ? and deleted_at is null;
//
// update fruit set color = ?, price = ?, quantity = ?, updated_at = ?
//   where name = ? and deleted_at is null
//   returning name, color, price, quantity;
//
// update fruit set deleted_at = ?, updated_at = ?
//   where name = ? and deleted_at is null
//   returning name;
//
// select name, color, price, quantity from fruit
//   where deleted_at is null
//   order by updated_at desc
//   limit 100;

const upsert_sql = "insert into fruit (name, color, price, quantity, created_at, updated_at, deleted_at)
values (?, ?, ?, ?, ?, ?, null)
on conflict(name) do update set
  color = excluded.color,
  price = excluded.price,
  quantity = excluded.quantity,
  updated_at = excluded.updated_at,
  deleted_at = null
returning name, color, price, quantity;"

const select_by_name_sql = "select name, color, price, quantity from fruit where name = ? and deleted_at is null;"

const update_by_name_sql = "update fruit set color = ?, price = ?, quantity = ?, updated_at = ? where name = ? and deleted_at is null returning name, color, price, quantity;"

const soft_delete_by_name_sql = "update fruit set deleted_at = ?, updated_at = ? where name = ? and deleted_at is null returning name;"

const last_100_sql = "select name, color, price, quantity from fruit where deleted_at is null order by updated_at desc limit 100;"

fn unix_seconds_now() -> Int {
  let #(s, _) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds
  s
}

fn opt_text_for_db(o: Option(String)) -> String {
  case o {
    Some(s) -> s
    None -> ""
  }
}

fn opt_float_for_db(o: Option(Float)) -> Float {
  case o {
    Some(f) -> f
    None -> 0.0
  }
}

fn opt_int_for_db(o: Option(Int)) -> Int {
  case o {
    Some(i) -> i
    None -> 0
  }
}

fn opt_string_from_db(s: String) -> Option(String) {
  case s {
    "" -> None
    _ -> Some(s)
  }
}

fn fruit_row_decoder() -> decode.Decoder(Fruit) {
  use name <- decode.field(0, decode.string)
  use color <- decode.field(1, decode.string)
  use price <- decode.field(2, decode.float)
  use quantity <- decode.field(3, decode.int)
  decode.success(Fruit(
    name: Some(name),
    color: opt_string_from_db(color),
    price: Some(price),
    quantity: Some(quantity),
    identities: ByName(name:),
  ))
}

fn not_found_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "fruit not found: " <> op, -1)
}

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

/// Upsert a fruit by the `ByName` identity.
pub fn upsert_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: Option(String),
  price: Option(Float),
  quantity: Option(Int),
) -> Result(Fruit, sqlight.Error) {
  let now = unix_seconds_now()
  let c = opt_text_for_db(color)
  let p = opt_float_for_db(price)
  let q = opt_int_for_db(quantity)
  use rows <- result.try(sqlight.query(
    upsert_sql,
    on: conn,
    with: [
      sqlight.text(name),
      sqlight.text(c),
      sqlight.float(p),
      sqlight.int(q),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: fruit_row_decoder(),
  ))
  case rows {
    [fruit, ..] -> Ok(fruit)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

/// Get a fruit by the `ByName` identity.
pub fn get_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(Option(Fruit), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_by_name_sql,
    on: conn,
    with: [sqlight.text(name)],
    expecting: fruit_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [fruit, ..] -> Ok(Some(fruit))
  }
}

/// Update a fruit by the `ByName` identity.
pub fn update_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: Option(String),
  price: Option(Float),
  quantity: Option(Int),
) -> Result(Fruit, sqlight.Error) {
  let now = unix_seconds_now()
  let c = opt_text_for_db(color)
  let p = opt_float_for_db(price)
  let q = opt_int_for_db(quantity)
  use rows <- result.try(sqlight.query(
    update_by_name_sql,
    on: conn,
    with: [
      sqlight.text(c),
      sqlight.float(p),
      sqlight.int(q),
      sqlight.int(now),
      sqlight.text(name),
    ],
    expecting: fruit_row_decoder(),
  ))
  case rows {
    [fruit, ..] -> Ok(fruit)
    [] -> Error(not_found_error("update_fruit_by_name"))
  }
}

/// Delete a fruit by the `ByName` identity.
pub fn delete_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(Nil, sqlight.Error) {
  let now = unix_seconds_now()
  use rows <- result.try(sqlight.query(
    soft_delete_by_name_sql,
    on: conn,
    with: [sqlight.int(now), sqlight.int(now), sqlight.text(name)],
    expecting: {
      use _n <- decode.field(0, decode.string)
      decode.success(Nil)
    },
  ))
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_error("delete_fruit_by_name"))
  }
}

/// List up to 100 recently edited fruit rows.
pub fn last_100_edited_fruit(
  conn: sqlight.Connection,
) -> Result(List(Fruit), sqlight.Error) {
  sqlight.query(
    last_100_sql,
    on: conn,
    with: [],
    expecting: fruit_row_decoder(),
  )
}
