import generators/migration/migration_sql
import gleam/list
import gleam/string
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition,
}

pub fn entity_data_fields(entity: EntityDefinition) -> List(FieldDefinition) {
  list.filter(entity.fields, fn(f) {
    f.label != "identities"
    && f.label != "relationships"
    && !migration_sql.type_is_list(f.type_)
  })
}

/// `List(_)` fields are not columns on the main table row; decoders use `[]` until join-loaded lists exist.
pub fn entity_row_list_placeholder_fields(
  entity: EntityDefinition,
) -> List(FieldDefinition) {
  list.filter(entity.fields, fn(f) {
    f.label != "identities"
    && f.label != "relationships"
    && migration_sql.type_is_list(f.type_)
  })
}

fn q(c: String) -> String {
  migration_sql.quote_ident(c)
}

fn comma_join_q(xs: List(String)) -> String {
  list.map(xs, q)
  |> string.join(", ")
}

/// Same as [`upsert_sql`] but no `RETURNING` clause — for command executors that
/// only need `Result(Nil, _)`.
pub fn upsert_sql_exec(
  table: String,
  data_cols: List(String),
  id_cols: List(String),
) -> String {
  let insert_col_names =
    list.flatten([
      data_cols,
      ["created_at", "updated_at", "deleted_at"],
    ])
  let placeholders_before_null = list.repeat("?", list.length(data_cols) + 2)
  let value_placeholders =
    string.join(list.flatten([placeholders_before_null, ["null"]]), ", ")
  let conflict_cols = comma_join_q(id_cols)
  let non_id_data = list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
  let update_sets =
    list.map(non_id_data, fn(c) { q(c) <> " = excluded." <> q(c) })
    |> list.append([
      q("updated_at") <> " = excluded." <> q("updated_at"),
      q("deleted_at") <> " = null",
    ])
    |> string.join(",\n  ")
  "insert into "
  <> q(table)
  <> " ("
  <> comma_join_q(insert_col_names)
  <> ")\nvalues ("
  <> value_placeholders
  <> ")\non conflict("
  <> conflict_cols
  <> ") do update set\n  "
  <> update_sets
  <> ";"
}

pub fn upsert_sql(
  table: String,
  data_cols: List(String),
  id_cols: List(String),
  returning_cols: List(String),
) -> String {
  let insert_col_names =
    list.flatten([
      data_cols,
      ["created_at", "updated_at", "deleted_at"],
    ])
  let placeholders_before_null = list.repeat("?", list.length(data_cols) + 2)
  let value_placeholders =
    string.join(list.flatten([placeholders_before_null, ["null"]]), ", ")
  let conflict_cols = comma_join_q(id_cols)
  let non_id_data = list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
  let update_sets =
    list.map(non_id_data, fn(c) { q(c) <> " = excluded." <> q(c) })
    |> list.append([
      q("updated_at") <> " = excluded." <> q("updated_at"),
      q("deleted_at") <> " = null",
    ])
    |> string.join(",\n  ")
  let returning = comma_join_q(returning_cols)
  "insert into "
  <> q(table)
  <> " ("
  <> comma_join_q(insert_col_names)
  <> ")\nvalues ("
  <> value_placeholders
  <> ")\non conflict("
  <> conflict_cols
  <> ") do update set\n  "
  <> update_sets
  <> "\nreturning "
  <> returning
  <> ";"
}

/// [`update_by_identity_sql`] without `RETURNING` — for command batch execution.
pub fn update_by_identity_sql_exec(
  table: String,
  data_cols: List(String),
  id_cols: List(String),
) -> String {
  let non_id = list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
  let set_parts =
    list.map(non_id, fn(c) { q(c) <> " = ?" })
    |> list.append([q("updated_at") <> " = ?"])
  let set_clause = string.join(set_parts, ", ")
  let where_id =
    id_cols
    |> list.map(fn(c) { q(c) <> " = ?" })
    |> string.join(" and ")
  "update "
  <> q(table)
  <> " set "
  <> set_clause
  <> " where "
  <> where_id
  <> " and "
  <> q("deleted_at")
  <> " is null;"
}

/// [`update_by_row_id_sql`] without `RETURNING`.
pub fn update_by_row_id_sql_exec(table: String, data_cols: List(String)) -> String {
  let data_sets = list.map(data_cols, fn(c) { q(c) <> " = ?" })
  let set_parts = list.append(data_sets, [q("updated_at") <> " = ?"])
  let set_clause = string.join(set_parts, ", ")
  "update "
  <> q(table)
  <> " set "
  <> set_clause
  <> " where "
  <> q("id")
  <> " = ? and "
  <> q("deleted_at")
  <> " is null;"
}

/// [`soft_delete_by_identity_sql`] without `RETURNING`.
pub fn soft_delete_by_identity_sql_exec(
  table: String,
  id_cols: List(String),
) -> String {
  let where_id =
    id_cols
    |> list.map(fn(c) { q(c) <> " = ?" })
    |> string.join(" and ")
  "update "
  <> q(table)
  <> " set "
  <> q("deleted_at")
  <> " = ?, "
  <> q("updated_at")
  <> " = ? where "
  <> where_id
  <> " and "
  <> q("deleted_at")
  <> " is null;"
}

pub fn select_by_identity_sql(
  table: String,
  returning_cols: List(String),
  id_cols: List(String),
) -> String {
  let where_id =
    id_cols
    |> list.map(fn(c) { q(c) <> " = ?" })
    |> string.join(" and ")
  "select "
  <> comma_join_q(returning_cols)
  <> " from "
  <> q(table)
  <> " where "
  <> where_id
  <> " and "
  <> q("deleted_at")
  <> " is null;"
}

pub fn update_by_identity_sql(
  table: String,
  data_cols: List(String),
  id_cols: List(String),
  returning_cols: List(String),
) -> String {
  let non_id = list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
  let set_parts =
    list.map(non_id, fn(c) { q(c) <> " = ?" })
    |> list.append([q("updated_at") <> " = ?"])
  let set_clause = string.join(set_parts, ", ")
  let where_id =
    id_cols
    |> list.map(fn(c) { q(c) <> " = ?" })
    |> string.join(" and ")
  "update "
  <> q(table)
  <> " set "
  <> set_clause
  <> " where "
  <> where_id
  <> " and "
  <> q("deleted_at")
  <> " is null returning "
  <> comma_join_q(returning_cols)
  <> ";"
}

/// Update all persisted scalar columns including natural-key fields; `where` uses row `id`.
pub fn update_by_row_id_sql(
  table: String,
  data_cols: List(String),
  returning_cols: List(String),
) -> String {
  let data_sets = list.map(data_cols, fn(c) { q(c) <> " = ?" })
  let set_parts = list.append(data_sets, [q("updated_at") <> " = ?"])
  let set_clause = string.join(set_parts, ", ")
  "update "
  <> q(table)
  <> " set "
  <> set_clause
  <> " where "
  <> q("id")
  <> " = ? and "
  <> q("deleted_at")
  <> " is null returning "
  <> comma_join_q(returning_cols)
  <> ";"
}

pub fn soft_delete_by_identity_sql(
  table: String,
  id_cols: List(String),
  returning_cols: List(String),
) -> String {
  let where_id =
    id_cols
    |> list.map(fn(c) { q(c) <> " = ?" })
    |> string.join(" and ")
  "update "
  <> q(table)
  <> " set "
  <> q("deleted_at")
  <> " = ?, "
  <> q("updated_at")
  <> " = ? where "
  <> where_id
  <> " and "
  <> q("deleted_at")
  <> " is null returning "
  <> comma_join_q(returning_cols)
  <> ";"
}

pub fn last_100_sql(table: String, returning_cols: List(String)) -> String {
  "select "
  <> comma_join_q(returning_cols)
  <> " from "
  <> q(table)
  <> " where "
  <> q("deleted_at")
  <> " is null order by "
  <> q("updated_at")
  <> " desc limit 100;"
}

pub fn lt_column_asc_sql(
  table: String,
  returning_cols: List(String),
  column: String,
) -> String {
  "select "
  <> comma_join_q(returning_cols)
  <> " from "
  <> q(table)
  <> " where "
  <> q("deleted_at")
  <> " is null and "
  <> q(column)
  <> " < ? order by "
  <> q(column)
  <> " asc;"
}

pub fn eq_column_order_sql(
  table: String,
  returning_cols: List(String),
  filter_column: String,
  order_column: String,
  order_desc: Bool,
) -> String {
  let order_dir = case order_desc {
    True -> " desc"
    False -> " asc"
  }
  "select "
  <> comma_join_q(returning_cols)
  <> " from "
  <> q(table)
  <> " where "
  <> q("deleted_at")
  <> " is null and "
  <> q(filter_column)
  <> " = ? order by "
  <> q(order_column)
  <> order_dir
  <> ";"
}

pub fn full_row_columns(data_cols: List(String)) -> List(String) {
  list.flatten([
    data_cols,
    ["id", "created_at", "updated_at", "deleted_at"],
  ])
}

pub fn soft_delete_returning(id_cols: List(String)) -> List(String) {
  id_cols
}
