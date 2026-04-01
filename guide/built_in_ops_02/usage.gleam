//// Guide 02 — built-in operations (usage)
////
//// Workflow (manual loop you do at the keyboard):
//// 1. `gleam run -- src/guide/built_in_ops_02/schema.gleam`
//// 2. Open a **persistent** DB (file path) if you want to see additive migrate;
////    `:memory:` is fine for a single-generation demo.
//// 3. `migrate(conn)` — safe to call repeatedly; reconciles pragma vs desired schema.
//// 4. Use generated CRUD + `last_100_edited_guide02item` (same pattern as lesson 01).
////
//// Compare `schema_db/query.gleam`: `last_100_*` is always emitted for each entity.

import gleam/io
import gleam/list
import gleam/option
import gleam/string
import guide/built_in_ops_02/schema_db/api as g02
import sqlight

pub fn walkthrough() {
  let assert Ok(conn) = sqlight.connect(sqlight.in_memory())
  let assert Ok(Nil) = g02.migrate(conn)

  let assert Ok(#(row, _magic)) =
    g02.upsert_one_guide02item(
      conn,
      row: g02.by_guide02item_name(
        name: "item-a",
        note: option.None,
        sku: option.Some("SKU-1"),
      ),
    )
  io.println(string.inspect(row))

  let assert Ok(recent) = g02.last_100_edited_guide02item(conn)
  io.println("recent: " <> string.inspect(list.length(recent)))
  Nil
}
