import case_studies/fruit_db/cmd
import case_studies/fruit_db/get
import case_studies/fruit_db/migration
import case_studies/fruit_db/query
import case_studies/fruit_schema
import gleam/option
import sqlight
import swil/dsl

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn query_cheap_fruit(
  conn: sqlight.Connection,
  max_price max_price: Float,
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  query.query_cheap_fruit(conn, max_price: max_price)
}

pub fn page_edited_fruit(
  conn: sqlight.Connection,
  limit limit: Int,
  offset offset: Int,
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  query.page_edited_fruit(conn, limit: limit, offset: offset)
}

pub fn last_100_edited_fruit(
  conn: sqlight.Connection,
) -> Result(List(#(fruit_schema.Fruit, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_fruit(conn)
}

pub fn get_fruit_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(fruit_schema.Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_fruit_by_id(conn, id: id)
}

pub fn get_fruit_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(fruit_schema.Fruit, dsl.MagicFields)),
  sqlight.Error,
) {
  get.get_fruit_by_name(conn, name: name)
}

pub fn execute_fruit_cmds(
  conn: sqlight.Connection,
  commands commands: List(cmd.FruitCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd.execute_fruit_cmds(conn, commands)
}
