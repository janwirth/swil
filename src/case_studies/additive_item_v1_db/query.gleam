import case_studies/additive_item_v1_db/row
import case_studies/additive_item_v1_schema
import sqlight
import swil/dsl/dsl

const last_100_item_sql = "select \"name\", \"age\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"item\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// List up to 100 recently edited item rows.
pub fn last_100_edited_item(
  conn: sqlight.Connection,
) -> Result(
  List(#(additive_item_v1_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    last_100_item_sql,
    on: conn,
    with: [],
    expecting: row.item_with_magic_row_decoder(),
  )
}
