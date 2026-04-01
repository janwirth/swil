import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sqlight

/// User-owned table names (`sqlite_master`, excluding `sqlite_%`), sorted for comparison.
pub fn user_table_names(
  conn: sqlight.Connection,
) -> Result(List(String), sqlight.Error) {
  sqlight.query(
    "select name from sqlite_master where type = 'table' and name not like 'sqlite_%' order by name",
    on: conn,
    with: [],
    expecting: {
      use name <- decode.field(0, decode.string)
      decode.success(name)
    },
  )
}

/// Drops every user table except [keep] (so this version needs no names of other aggregates).
pub fn drop_user_tables_except(
  conn: sqlight.Connection,
  keep: String,
) -> Result(Nil, sqlight.Error) {
  drop_user_tables_except_any(conn, [keep])
}

/// Drops every user table whose name is not in [keep].
pub fn drop_user_tables_except_any(
  conn: sqlight.Connection,
  keep: List(String),
) -> Result(Nil, sqlight.Error) {
  use tables <- result.try(user_table_names(conn))
  list.try_each(tables, fn(t) {
    case list.contains(keep, t) {
      True -> Ok(Nil)
      False -> sqlight.exec("drop table if exists " <> t <> ";", conn)
    }
  })
}

pub type TableInfoRow {
  TableInfoRow(
    cid: Int,
    name: String,
    type_: String,
    notnull: Int,
    dflt: Option(String),
    pk: Int,
  )
}

fn table_info_row_from_tuple(
  row: #(Int, String, String, Int, Option(String), Int),
) -> TableInfoRow {
  let #(cid, name, type_, notnull, dflt, pk) = row
  TableInfoRow(cid:, name:, type_:, notnull:, dflt:, pk:)
}

/// Structured `pragma table_info(table)` rows (same order as SQLite).
pub fn table_info_rows(
  conn: sqlight.Connection,
  table: String,
) -> Result(List(TableInfoRow), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    "pragma table_info(" <> table <> ")",
    on: conn,
    with: [],
    expecting: table_info_row_decoder(),
  ))
  Ok(list.map(rows, table_info_row_from_tuple))
}

/// Tab-separated `pragma table_info(table)` snapshot (header + rows), stable for tests.
pub fn table_info_tsv(
  conn: sqlight.Connection,
  table: String,
) -> Result(String, sqlight.Error) {
  use rows <- result.try(table_info_rows(conn, table))
  Ok(format_table_info_tsv_rows(rows))
}

/// Tab-separated `pragma index_list(table)` snapshot.
pub fn index_list_tsv(
  conn: sqlight.Connection,
  table: String,
) -> Result(String, sqlight.Error) {
  use rows <- result.try(sqlight.query(
    "pragma index_list(" <> table <> ")",
    on: conn,
    with: [],
    expecting: index_list_row_decoder(),
  ))
  Ok(format_index_list_tsv(rows))
}

/// Tab-separated `pragma index_info(index_name)` snapshot.
pub fn index_info_tsv(
  conn: sqlight.Connection,
  index_name: String,
) -> Result(String, sqlight.Error) {
  use rows <- result.try(sqlight.query(
    "pragma index_info(" <> index_name <> ")",
    on: conn,
    with: [],
    expecting: index_info_row_decoder(),
  ))
  Ok(format_index_info_tsv(rows))
}

/// Sorts `pragma table_info` body rows by column name and renumbers `cid` 0..n-1 so
/// `ALTER TABLE … ADD COLUMN` (always appends in SQLite) still matches the logical shape
/// from `CREATE TABLE` (canonical column order in fixtures).
fn normalize_table_info_tsv(tsv: String) -> String {
  let lines = string.split(tsv, "\n")
  case lines {
    [] -> tsv
    [header, ..rest] -> {
      let parsed =
        list.filter_map(rest, fn(line) {
          case string.split(line, "\t") {
            [_cid, name, typ, notnull, dflt, pk] ->
              Ok(#(name, typ, notnull, dflt, pk))
            _ -> Error(Nil)
          }
        })
      let sorted =
        list.sort(parsed, fn(a, b) { string.compare(a.0, b.0) })
      let body =
        list.index_map(sorted, fn(row, i) {
          let #(name, typ, notnull, dflt, pk) = row
          int.to_string(i)
          <> "\t"
          <> name
          <> "\t"
          <> typ
          <> "\t"
          <> notnull
          <> "\t"
          <> dflt
          <> "\t"
          <> pk
        })
      string.join([header, ..body], "\n")
    }
  }
}

/// Asserts the DB has exactly these user tables (no more, no less), then checks
/// `table_info`, `index_list`, and `index_info` for [table] / [unique_index_name] with
/// exact TSV equality (no trimming).
///
/// `table_info` is compared in **normalized** form (rows sorted by column name, `cid`
/// reassigned) so additive `ADD COLUMN` migrations match fixtures built for `CREATE TABLE`.
pub fn assert_pragma_snapshot(
  conn: sqlight.Connection,
  exact_user_tables: List(String),
  table: String,
  expected_table_info: String,
  expected_indexes: String,
  unique_index_name: String,
  expected_index_info: String,
) -> Nil {
  let assert Ok(got_tables) = user_table_names(conn)
  let want_sorted = list.sort(exact_user_tables, string.compare)
  let got_sorted = list.sort(got_tables, string.compare)
  let assert True = got_sorted == want_sorted
  let assert Ok(got_info) = table_info_tsv(conn, table)
  let assert Ok(got_list) = index_list_tsv(conn, table)
  let assert Ok(got_ix) = index_info_tsv(conn, unique_index_name)
  let assert True =
    normalize_table_info_tsv(got_info) == normalize_table_info_tsv(expected_table_info)
  let assert True = got_list == expected_indexes
  let assert True = got_ix == expected_index_info
  Nil
}

fn table_info_row_decoder() -> decode.Decoder(
  #(Int, String, String, Int, Option(String), Int),
) {
  use cid <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  use type_ <- decode.field(2, decode.string)
  use notnull <- decode.field(3, decode.int)
  use dflt <- decode.field(4, decode.optional(decode.string))
  use pk <- decode.field(5, decode.int)
  decode.success(#(cid, name, type_, notnull, dflt, pk))
}

fn format_table_info_tsv_rows(rows: List(TableInfoRow)) -> String {
  let header = "cid\tname\ttype\tnotnull\tdflt_value\tpk"
  let lines =
    list.map(rows, fn(r) {
      let dflt_str = case r.dflt {
        None -> "NULL"
        Some("") -> "NULL"
        Some(s) -> s
      }
      int.to_string(r.cid)
      <> "\t"
      <> r.name
      <> "\t"
      <> r.type_
      <> "\t"
      <> int.to_string(r.notnull)
      <> "\t"
      <> dflt_str
      <> "\t"
      <> int.to_string(r.pk)
    })
  string.join([header, ..lines], "\n")
}

fn index_list_row_decoder() -> decode.Decoder(#(Int, String, Int, String, Int)) {
  use seq <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  use unique <- decode.field(2, decode.int)
  use origin <- decode.field(3, decode.string)
  use partial <- decode.field(4, decode.int)
  decode.success(#(seq, name, unique, origin, partial))
}

fn format_index_list_tsv(rows: List(#(Int, String, Int, String, Int))) -> String {
  let header = "seq\tname\tunique\torigin\tpartial"
  let lines =
    list.map(rows, fn(r) {
      let #(seq, name, unique, origin, partial) = r
      int.to_string(seq)
      <> "\t"
      <> name
      <> "\t"
      <> int.to_string(unique)
      <> "\t"
      <> origin
      <> "\t"
      <> int.to_string(partial)
    })
  string.join([header, ..lines], "\n")
}

fn index_info_row_decoder() -> decode.Decoder(#(Int, Int, String)) {
  use seqno <- decode.field(0, decode.int)
  use cid <- decode.field(1, decode.int)
  use name <- decode.field(2, decode.string)
  decode.success(#(seqno, cid, name))
}

fn format_index_info_tsv(rows: List(#(Int, Int, String))) -> String {
  let header = "seqno\tcid\tname"
  let lines =
    list.map(rows, fn(r) {
      let #(seqno, cid, name) = r
      int.to_string(seqno) <> "\t" <> int.to_string(cid) <> "\t" <> name
    })
  string.join([header, ..lines], "\n")
}
