/// Thin wrappers used by generated `get.gleam` modules.
///
/// `one/4` turns the `List` returned by `sqlight.query` into an `Option`.
/// `many/4` is a pass-through included for import uniformity in generated code.
import gleam/dynamic/decode
import gleam/option
import gleam/result
import sqlight

/// Execute `sql` and return the first result row, or `None` if the result set is empty.
pub fn one(
  conn: sqlight.Connection,
  sql: String,
  binds: List(sqlight.Value),
  decoder: decode.Decoder(a),
) -> Result(option.Option(a), sqlight.Error) {
  use rows <- result.try(sqlight.query(sql, on: conn, with: binds, expecting: decoder))
  case rows {
    [] -> Ok(option.None)
    [r, ..] -> Ok(option.Some(r))
  }
}

/// Execute `sql` and return all result rows.
pub fn many(
  conn: sqlight.Connection,
  sql: String,
  binds: List(sqlight.Value),
  decoder: decode.Decoder(a),
) -> Result(List(a), sqlight.Error) {
  sqlight.query(sql, on: conn, with: binds, expecting: decoder)
}
