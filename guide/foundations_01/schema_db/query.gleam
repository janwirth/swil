import guide/foundations_01/schema
import guide/foundations_01/schema_db/row
import sqlight
import swil/dsl

const last_100_guide01item_sql = "select \"name\", \"note\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"guide01item\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// List up to 100 recently edited guide01item rows.
pub fn last_100_edited_guide01item(
  conn: sqlight.Connection,
) -> Result(List(#(schema.Guide01Item, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_guide01item_sql,
    on: conn,
    with: [],
    expecting: row.guide01item_with_magic_row_decoder(),
  )
}
