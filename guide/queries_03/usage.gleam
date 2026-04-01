//// Guide 03 — queries (usage)
////
//// 1. `gleam run -- src/guide/queries_03/schema.gleam`
//// 2. `migrate(conn)` then seed with `upsert_one_*`.
//// 3. Call the generated `query_*` from `schema_db/api` with extra parameters matching your spec.

import gleam/io
import gleam/list
import gleam/option
import gleam/string
import guide/queries_03/schema_db/api as g03
import sqlight

pub fn walkthrough() {
  let assert Ok(conn) = sqlight.connect(sqlight.in_memory())
  let assert Ok(Nil) = g03.migrate(conn)

  let assert Ok(_) =
    g03.upsert_one_guide03note(
      conn,
      row: g03.by_guide03note_title(
        title: "alpha-note",
        body: option.Some("hello"),
      ),
    )
  let assert Ok(_) =
    g03.upsert_one_guide03note(
      conn,
      row: g03.by_guide03note_title(title: "beta-note", body: option.None),
    )

  let assert Ok(rows) =
    g03.query_guide03_notes_by_title_prefix(conn, prefix: "alpha")
  io.println(string.inspect(list.length(rows)))
  Nil
}
