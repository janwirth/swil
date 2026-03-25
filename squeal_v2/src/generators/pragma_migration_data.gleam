import gleam/int
import gleam/list
import gleam/string

pub type PragmaMigrationData {
  PragmaMigrationData(
    table: String,
    col_type: String,
    index_suffix: String,
    index_name: String,
    create_table_sql: String,
    create_index_sql: String,
    expected_table_info: String,
    expected_index_list: String,
    expected_index_info: String,
    wanted_rows: List(#(String, String, Int, Int)),
    apply_one_none_panic: String,
    reconcile_table_info_rows_stmt: String,
    panic_no_conv: String,
  )
}

fn gleam_quote(s: String) -> String {
  string.append("\"", string.append(s, "\""))
}

pub fn columns_wanted_line(
  data: PragmaMigrationData,
  row: #(String, String, Int, Int),
) -> String {
  let #(n, t, nn, pk) = row
  string.concat([
    "  ",
    data.col_type,
    "(",
    gleam_quote(n),
    ", ",
    gleam_quote(t),
    ", ",
    int.to_string(nn),
    ", ",
    int.to_string(pk),
    "),",
  ])
}

pub fn columns_wanted_block(data: PragmaMigrationData) -> String {
  data.wanted_rows
  |> list.map(columns_wanted_line(data, _))
  |> string.join("\n")
}
