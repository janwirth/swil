import gleam/list
import gleam/string

pub fn sql_doc_comment(
  table: String,
  data_cols: List(String),
  id_cols: List(String),
  returning: List(String),
) -> String {
  let insert_cols = string.join(data_cols, ", ")
  let qmarks =
    list.repeat("?", list.length(data_cols) + 2)
    |> string.join(", ")
  let on_up =
    list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
    |> list.map(fn(c) { c <> " = excluded." <> c })
    |> string.join(",\n//     ")
  let non_id_cols = list.filter(data_cols, fn(c) { !list.contains(id_cols, c) })
  let where_sql =
    list.map(id_cols, fn(c) { c <> " = ?" })
    |> string.join(" and ")
  let update_example_sets = case non_id_cols {
    [] -> "updated_at = ?"
    cols ->
      string.join(list.map(cols, fn(c) { c <> " = ?" }), ", ")
      <> ", updated_at = ?"
  }
  let returning_full = string.join(returning, ", ")
  let soft_ret_example = string.join(id_cols, ", ")
  "// --- SQL ("
  <> table
  <> " table shape matches `example_migration_"
  <> table
  <> "` / pragma migrations) ---\n//\n// insert into "
  <> table
  <> " ("
  <> insert_cols
  <> ", created_at, updated_at, deleted_at)\n//   values ("
  <> qmarks
  <> ", null)\n//   on conflict("
  <> string.join(id_cols, ", ")
  <> ") do update set\n//     "
  <> on_up
  <> ",\n//     updated_at = excluded.updated_at,\n//     deleted_at = null;\n//\n// select "
  <> string.join(returning, ", ")
  <> " from "
  <> table
  <> "\n//   where "
  <> where_sql
  <> " and deleted_at is null;\n//\n// update "
  <> table
  <> " set "
  <> update_example_sets
  <> "\n//   where "
  <> where_sql
  <> " and deleted_at is null\n//   returning "
  <> returning_full
  <> ";\n//\n// update "
  <> table
  <> " set deleted_at = ?, updated_at = ?\n//   where "
  <> where_sql
  <> " and deleted_at is null\n//   returning "
  <> soft_ret_example
  <> ";\n//\n// select "
  <> string.join(returning, ", ")
  <> " from "
  <> table
  <> "\n//   where deleted_at is null\n//   order by updated_at desc\n//   limit 100;\n\n"
}
