import case_studies/additive_item_v1_db/cmd
import case_studies/additive_item_v1_db/get
import case_studies/additive_item_v1_db/migration
import case_studies/additive_item_v1_db/query
import case_studies/additive_item_v1_schema
import gleam/option
import sqlight
import swil/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn page_edited_item(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(
  List(#(additive_item_v1_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  query.page_edited_item(conn, limit: limit, offset: offset)
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

pub fn execute_item_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.ItemCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_item_cmds(conn, commands)
}
