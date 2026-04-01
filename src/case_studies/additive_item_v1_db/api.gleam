pub type ItemByNameAndAge {
  ItemByNameAndAge
}

pub type ItemUpsertRow(by) {
  ItemUpsertRow(
    run: fn(sqlight.Connection) ->
      Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error),
  )
}

fn run_item_upsert_row(
  row: ItemUpsertRow(by),
  conn: sqlight.Connection,
) -> Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error) {
  let ItemUpsertRow(run:) = row
  run(conn)
}

import case_studies/additive_item_v1_db/delete
import case_studies/additive_item_v1_db/get
import case_studies/additive_item_v1_db/migration
import case_studies/additive_item_v1_db/query
import case_studies/additive_item_v1_db/upsert
import case_studies/additive_item_v1_schema
import gleam/list
import gleam/option
import sqlight
import swil/dsl/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn last_100_edited_item(
  conn: sqlight.Connection,
) -> Result(
  List(#(additive_item_v1_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  query.last_100_edited_item(conn)
}

pub fn get_item_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(additive_item_v1_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_item_by_id(conn, id: id)
}

pub fn update_item_by_id(
  conn: sqlight.Connection,
  id id: Int,
  name name: option.Option(String),
  age age: option.Option(Int),
) -> Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error) {
  upsert.update_item_by_id(conn, id: id, name: name, age: age)
}

pub fn delete_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
) -> Result(Nil, sqlight.Error) {
  delete.delete_item_by_name_and_age(conn, name: name, age: age)
}

pub fn update_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
) -> Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error) {
  upsert.update_item_by_name_and_age(conn, name: name, age: age)
}

pub fn get_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
) -> Result(
  option.Option(#(additive_item_v1_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_item_by_name_and_age(conn, name: name, age: age)
}

pub fn by_item_name_and_age(
  name name: String,
  age age: Int,
) -> ItemUpsertRow(ItemByNameAndAge) {
  ItemUpsertRow(fn(conn) {
    upsert.upsert_item_by_name_and_age(conn, name: name, age: age)
  })
}

pub fn upsert_many_item(
  conn: sqlight.Connection,
  rows rows: List(ItemUpsertRow(by)),
) -> Result(
  List(#(additive_item_v1_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  list.try_map(rows, fn(row) { run_item_upsert_row(row, conn) })
}

pub fn upsert_one_item(
  conn: sqlight.Connection,
  row row: ItemUpsertRow(by),
) -> Result(#(additive_item_v1_schema.Item, dsl.MagicFields), sqlight.Error) {
  run_item_upsert_row(row, conn)
}
