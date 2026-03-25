import case_studies/fruit_db/migration
import case_studies/fruit_schema.{type Fruit, ByName, Fruit}
import dsl
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import sqlight

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
// select name, color, price, quantity, id, created_at, updated_at, deleted_at from fruit
//   where name = ? and deleted_at is null;
//
// update fruit set color = ?, price = ?, quantity = ?, updated_at = ?
//   where name = ? and deleted_at is null
//   returning name, color, price, quantity, id, created_at, updated_at, deleted_at;
//
// update fruit set deleted_at = ?, updated_at = ?
//   where name = ? and deleted_at is null
//   returning name;
//
// select name, color, price, quantity, id, created_at, updated_at, deleted_at from fruit
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
returning name, color, price, quantity, id, created_at, updated_at, deleted_at;"

const select_by_name_sql = "select name, color, price, quantity, id, created_at, updated_at, deleted_at from fruit where name = ? and deleted_at is null;"

const update_by_name_sql = "update fruit set color = ?, price = ?, quantity = ?, updated_at = ? where name = ? and deleted_at is null returning name, color, price, quantity, id, created_at, updated_at, deleted_at;"

const soft_delete_by_name_sql = "update fruit set deleted_at = ?, updated_at = ? where name = ? and deleted_at is null returning name;"

const last_100_sql = "select name, color, price, quantity, id, created_at, updated_at, deleted_at from fruit where deleted_at is null order by updated_at desc limit 100;"

const cheap_fruit_sql = "select name, color, price, quantity, id, created_at, updated_at, deleted_at from fruit where deleted_at is null and price < ? order by price asc;"

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

fn magic_from_db_row(
  id: Int,
  created_s: Int,
  updated_s: Int,
  deleted_raw: Option(Int),
) -> dsl.MagicFields {
  dsl.MagicFields(
    id:,
    created_at: timestamp.from_unix_seconds(created_s),
    updated_at: timestamp.from_unix_seconds(updated_s),
    deleted_at: case deleted_raw {
      Some(s) -> Some(timestamp.from_unix_seconds(s))
      None -> None
    },
  )
}

fn fruit_with_magic_row_decoder() -> decode.Decoder(#(Fruit, dsl.MagicFields)) {
  use name <- decode.field(0, decode.string)
  use color <- decode.field(1, decode.string)
  use price <- decode.field(2, decode.float)
  use quantity <- decode.field(3, decode.int)
  use id <- decode.field(4, decode.int)
  use created_at <- decode.field(5, decode.int)
  use updated_at <- decode.field(6, decode.int)
  use deleted_at_raw <- decode.field(7, decode.optional(decode.int))
  let fruit =
    Fruit(
      name: Some(name),
      color: opt_string_from_db(color),
      price: Some(price),
      quantity: Some(quantity),
      identities: ByName(name:),
    )
  decode.success(#(
    fruit,
    magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
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
) -> Result(#(Fruit, dsl.MagicFields), sqlight.Error) {
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
    expecting: fruit_with_magic_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(row)
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
) -> Result(Option(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_by_name_sql,
    on: conn,
    with: [sqlight.text(name)],
    expecting: fruit_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [row, ..] -> Ok(Some(row))
  }
}

/// Update a fruit by the `ByName` identity.
pub fn update_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
  color: Option(String),
  price: Option(Float),
  quantity: Option(Int),
) -> Result(#(Fruit, dsl.MagicFields), sqlight.Error) {
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
    expecting: fruit_with_magic_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(row)
    [] -> Error(not_found_error("update_fruit_by_name"))
  }
}

/// Delete a fruit by the `ByName` identity.
pub fn delete_fruit_by_name(
  conn: sqlight.Connection,
  name: String,
) -> Result(Nil, sqlight.Error) {
  let now = unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_by_name_sql,
      on: conn,
      with: [sqlight.int(now), sqlight.int(now), sqlight.text(name)],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_error("delete_fruit_by_name"))
  }
}

/// List up to 100 recently edited fruit rows.
pub fn last_100_edited_fruit(
  conn: sqlight.Connection,
) -> Result(List(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_sql,
    on: conn,
    with: [],
    expecting: fruit_with_magic_row_decoder(),
  )
}

/// Fruits with `price < max_price`, ordered by ascending price (see `query_cheap_fruit` spec).
pub fn query_cheap_fruit(
  conn: sqlight.Connection,
  max_price: Float,
) -> Result(List(#(Fruit, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    cheap_fruit_sql,
    on: conn,
    with: [sqlight.float(max_price)],
    expecting: fruit_with_magic_row_decoder(),
  )
}
