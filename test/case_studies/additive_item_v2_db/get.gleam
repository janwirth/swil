import case_studies/additive_item_v2_db/row
import case_studies/additive_item_v2_schema
import gleam/option
import sqlight
import swil/dsl/dsl
import swil/runtime/query

const select_item_by_id_sql = "select \"name\", \"age\", \"height\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"item\" where \"id\" = ? and \"deleted_at\" is null;"

const select_item_by_name_and_age_sql = "select \"name\", \"age\", \"height\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"item\" where \"name\" = ? and \"age\" = ? and \"deleted_at\" is null;"

const select_item_by_name_sql = "select \"name\", \"age\", \"height\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"item\" where \"name\" = ? and \"deleted_at\" is null;"

/// Get a item by the `ByNameAndAge` identity.
pub fn get_item_by_name_and_age(
  conn: sqlight.Connection,
  name name: String,
  age age: Int,
) -> Result(
  option.Option(#(additive_item_v2_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(
    conn,
    select_item_by_name_and_age_sql,
    [sqlight.text(name), sqlight.int(age)],
    row.item_with_magic_row_decoder(),
  )
}

/// Get a item by row id.
pub fn get_item_by_id(
  conn: sqlight.Connection,
  id id: Int,
) -> Result(
  option.Option(#(additive_item_v2_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_item_by_id_sql, [sqlight.int(id)], row.item_with_magic_row_decoder())
}

/// Get a item by the `ByName` identity.
pub fn get_item_by_name(
  conn: sqlight.Connection,
  name name: String,
) -> Result(
  option.Option(#(additive_item_v2_schema.Item, dsl.MagicFields)),
  sqlight.Error,
) {
  query.one(conn, select_item_by_name_sql, [sqlight.text(name)], row.item_with_magic_row_decoder())
}
