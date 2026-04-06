import gleam/option
import guide/foundations_01/schema
import guide/foundations_01/schema_db/cmd
import guide/foundations_01/schema_db/get
import guide/foundations_01/schema_db/migration
import guide/foundations_01/schema_db/query
import sqlight
import swil/dsl

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

pub fn get_guide01item_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(schema.Guide01Item, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_guide01item_by_name(conn, name: name)
}

pub fn execute_guide01item_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.Guide01ItemCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_guide01item_cmds(conn, commands)
}
