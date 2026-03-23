//// Run Cake queries via sqlight (logic adapted from cake_sqlight, MPL-2.0).

import cake.{
  type PreparedStatement, type ReadQuery, type WriteQuery, get_params, get_sql,
}
import cake/dialect/sqlite_dialect
import cake/param.{
  type Param, BoolParam, DateParam, FloatParam, IntParam, NullParam, StringParam,
}
import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/list
import gleam/string
import gleam/time/calendar
import sqlight.{type Connection, type Error, type Value}

pub fn run_read_query(
  query query: ReadQuery,
  decoder decoder: Decoder(a),
  db_connection db_connection: Connection,
) -> Result(List(a), Error) {
  let prepared_statement =
    query |> sqlite_dialect.read_query_to_prepared_statement
  run_prepared(prepared_statement, decoder, db_connection)
}

pub fn run_write_query(
  query query: WriteQuery(t),
  decoder decoder: Decoder(b),
  db_connection db_connection: Connection,
) -> Result(List(b), Error) {
  let prepared_statement =
    query |> sqlite_dialect.write_query_to_prepared_statement
  run_prepared(prepared_statement, decoder, db_connection)
}

fn run_prepared(
  prepared_statement: PreparedStatement,
  decoder: Decoder(a),
  db_connection: Connection,
) -> Result(List(a), Error) {
  let sql_string = prepared_statement |> get_sql
  let db_params =
    prepared_statement
    |> get_params
    |> list.map(with: cake_param_to_client_param)

  sql_string
  |> sqlight.query(on: db_connection, with: db_params, expecting: decoder)
}

fn cake_param_to_client_param(param param: Param) -> Value {
  case param {
    BoolParam(param) -> sqlight.bool(param)
    FloatParam(param) -> sqlight.float(param)
    IntParam(param) -> sqlight.int(param)
    StringParam(param) -> sqlight.text(param)
    NullParam -> sqlight.null()
    DateParam(param) -> {
      let calendar.Date(year, month, day) = param
      let year = year |> int.to_string |> string.pad_start(with: "0", to: 4)
      let month =
        month
        |> calendar.month_to_int
        |> int.to_string
        |> string.pad_start(with: "0", to: 2)
      let day = day |> int.to_string |> string.pad_start(with: "0", to: 2)
      let date = year <> "-" <> month <> "-" <> day

      date |> sqlight.text()
    }
  }
}
