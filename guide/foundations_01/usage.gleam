//// Guide 01 — foundations (usage)
////
//// 1. Generate DB modules (repo root): `gleam run -- src/guide/foundations_01/schema.gleam`
//// 2. `sqlight.connect` — here `:memory:`.
//// 3. `migrate(conn)` from `schema_db/api` before any reads/writes.
//// 4. Upsert via `by_*` row builders + `upsert_one_*` (identity + remaining columns).
//// 5. `get_*` / `delete_*` by the same natural key.
//// 6. `last_100_edited_*` — soft-delete filter, `updated_at` desc, limit 100.

import gleam/io
import gleam/list
import gleam/option
import gleam/string
import guide/foundations_01/schema_db/api as guide01_api
import sqlight

pub fn walkthrough() {
  let assert Ok(conn) = sqlight.connect(sqlight.in_memory())
  let assert Ok(Nil) = guide01_api.migrate(conn)

  let assert Ok(#(row, magic)) =
    guide01_api.upsert_one_guide01item(
      conn,
      row: guide01_api.by_guide01item_name(
        name: "alpha",
        note: option.Some("first row"),
      ),
    )
  io.println(string.inspect(#(row, magic)))

  let assert Ok(got) = guide01_api.get_guide01item_by_name(conn, name: "alpha")
  io.println(string.inspect(got))

  let assert Ok(recent) = guide01_api.last_100_edited_guide01item(conn)
  io.println("count: " <> string.inspect(list.length(recent)))

  let assert Ok(Nil) =
    guide01_api.delete_guide01item_by_name(conn, name: "alpha")

  Nil
}
