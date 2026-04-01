pub type Guide01itemByName {
  Guide01itemByName
}

pub type Guide01itemUpsertRow(by) {
  Guide01itemUpsertRow(
    run: fn(sqlight.Connection) ->
      Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error),
  )
}

fn run_guide01item_upsert_row(
  row: Guide01itemUpsertRow(by),
  conn: sqlight.Connection,
) -> Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error) {
  let Guide01itemUpsertRow(run:) = row
  run(conn)
}

import gleam/list
import gleam/option
import guide/foundations_01/schema
import guide/foundations_01/schema_db/delete
import guide/foundations_01/schema_db/get
import guide/foundations_01/schema_db/migration
import guide/foundations_01/schema_db/query
import guide/foundations_01/schema_db/upsert
import sqlight
import swil/dsl/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn last_100_edited_guide01item(
  conn: sqlight.Connection,
) -> Result(List(#(schema.Guide01Item, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_guide01item(conn)
}

pub fn get_guide01item_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(schema.Guide01Item, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_guide01item_by_id(conn, id: id)
}

pub fn update_guide01item_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  note note: option.Option(String),
) -> Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error) {
  upsert.update_guide01item_by_id(conn, id: id, name: name, note: note)
}

pub fn delete_guide01item_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(Nil, sqlight.Error) {
  delete.delete_guide01item_by_name(conn, name: name)
}

pub fn update_guide01item_by_name(
  conn: sqlight.Connection,
  name name: String,
  note note: option.Option(String),
) -> Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error) {
  upsert.update_guide01item_by_name(conn, name: name, note: note)
}

pub fn get_guide01item_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(schema.Guide01Item, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_guide01item_by_name(conn, name: name)
}

pub fn by_guide01item_name(
  name name: String,
  note note: option.Option(String),
) -> Guide01itemUpsertRow(Guide01itemByName) {
  Guide01itemUpsertRow(fn(conn) {
    upsert.upsert_guide01item_by_name(conn, name: name, note: note)
  })
}

pub fn upsert_many_guide01item(
  conn: sqlight.Connection,
  rows rows: List(Guide01itemUpsertRow(by)),
) -> Result(List(#(schema.Guide01Item, dsl.MagicFields)), sqlight.Error) {
  list.try_map(rows, fn(row) { run_guide01item_upsert_row(row, conn) })
}

pub fn upsert_one_guide01item(
  conn: sqlight.Connection,
  row row: Guide01itemUpsertRow(by),
) -> Result(#(schema.Guide01Item, dsl.MagicFields), sqlight.Error) {
  run_guide01item_upsert_row(row, conn)
}
