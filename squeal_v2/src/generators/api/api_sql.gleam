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

fn comma_join(xs: List(String)) -> String {
  string.join(xs, ", ")
}

pub fn upsert_sql(
  table: String,
  data_cols: List(String),
  id_cols: List(String),
  returning_cols: List(String),
) -> String {
  let insert_cols =
    list.flatten([
      data_cols,
      ["created_at", "updated_at", "deleted_at"],
    ])
    |> comma_join
  let placeholders_before_null = list.repeat("?", list.length(data_cols) + 2)
  let value_placeholders =
    string.join(list.flatten([placeholders_before_null, ["null"]]), ", ")
  let conflict_cols = comma_join(id_cols)
  let non_id_data = list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
  let update_sets =
    list.map(non_id_data, fn(c) { c <> " = excluded." <> c })
    |> list.append([
      "updated_at = excluded.updated_at",
      "deleted_at = null",
    ])
    |> string.join(",\n  ")
  let returning = comma_join(returning_cols)
  "insert into "
  <> table
  <> " ("
  <> insert_cols
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

pub fn select_by_identity_sql(
  table: String,
  returning_cols: List(String),
  id_cols: List(String),
) -> String {
  let where_id =
    id_cols
    |> list.map(fn(c) { c <> " = ?" })
    |> string.join(" and ")
  "select "
  <> comma_join(returning_cols)
  <> " from "
  <> table
  <> " where "
  <> where_id
  <> " and deleted_at is null;"
}

pub fn update_by_identity_sql(
  table: String,
  data_cols: List(String),
  id_cols: List(String),
  returning_cols: List(String),
) -> String {
  let non_id = list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
  let set_parts =
    list.map(non_id, fn(c) { c <> " = ?" })
    |> list.append(["updated_at = ?"])
  let set_clause = string.join(set_parts, ", ")
  let where_id =
    id_cols
    |> list.map(fn(c) { c <> " = ?" })
    |> string.join(" and ")
  "update "
  <> table
  <> " set "
  <> set_clause
  <> " where "
  <> where_id
  <> " and deleted_at is null returning "
  <> comma_join(returning_cols)
  <> ";"
}

pub fn soft_delete_by_identity_sql(
  table: String,
  id_cols: List(String),
  returning_cols: List(String),
) -> String {
  let where_id =
    id_cols
    |> list.map(fn(c) { c <> " = ?" })
    |> string.join(" and ")
  "update "
  <> table
  <> " set deleted_at = ?, updated_at = ? where "
  <> where_id
  <> " and deleted_at is null returning "
  <> comma_join(returning_cols)
  <> ";"
}

pub fn last_100_sql(table: String, returning_cols: List(String)) -> String {
  "select "
  <> comma_join(returning_cols)
  <> " from "
  <> table
  <> " where deleted_at is null order by updated_at desc limit 100;"
}

pub fn lt_column_asc_sql(
  table: String,
  returning_cols: List(String),
  column: String,
) -> String {
  "select "
  <> comma_join(returning_cols)
  <> " from "
  <> table
  <> " where deleted_at is null and "
  <> column
  <> " < ? order by "
  <> column
  <> " asc;"
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
