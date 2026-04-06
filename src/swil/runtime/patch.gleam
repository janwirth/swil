/// Patch command builder: accumulates `SET` clause parts and bindings for
/// UPDATE statements where only supplied fields are modified.
///
/// Usage:
///   patch.new()
///   |> patch.add_text("color", color)
///   |> patch.add_float("price", price)
///   |> patch.always_int("updated_at", now)
///   |> patch.build("fruit", "\"name\" = ? and \"deleted_at\" is null;", [sqlight.text(name)])
import gleam/list
import gleam/option
import gleam/string
import sqlight

pub opaque type PatchBuilder {
  PatchBuilder(set_parts: List(String), binds: List(sqlight.Value))
}

pub fn new() -> PatchBuilder {
  PatchBuilder([], [])
}

fn col_set(col: String) -> String {
  "\"" <> col <> "\" = ?"
}

/// Append a TEXT field only when the option is `Some`.
pub fn add_text(
  b: PatchBuilder,
  col: String,
  val: option.Option(String),
) -> PatchBuilder {
  case val {
    option.None -> b
    option.Some(v) ->
      PatchBuilder(
        set_parts: [col_set(col), ..b.set_parts],
        binds: [sqlight.text(v), ..b.binds],
      )
  }
}

/// Append a REAL field only when the option is `Some`.
pub fn add_float(
  b: PatchBuilder,
  col: String,
  val: option.Option(Float),
) -> PatchBuilder {
  case val {
    option.None -> b
    option.Some(v) ->
      PatchBuilder(
        set_parts: [col_set(col), ..b.set_parts],
        binds: [sqlight.float(v), ..b.binds],
      )
  }
}

/// Append an INTEGER field only when the option is `Some`.
pub fn add_int(
  b: PatchBuilder,
  col: String,
  val: option.Option(Int),
) -> PatchBuilder {
  case val {
    option.None -> b
    option.Some(v) ->
      PatchBuilder(
        set_parts: [col_set(col), ..b.set_parts],
        binds: [sqlight.int(v), ..b.binds],
      )
  }
}

/// Always append an INTEGER field (e.g. `updated_at`).
pub fn always_int(b: PatchBuilder, col: String, val: Int) -> PatchBuilder {
  PatchBuilder(
    set_parts: [col_set(col), ..b.set_parts],
    binds: [sqlight.int(val), ..b.binds],
  )
}

/// Build the final `#(sql, binds)` pair.
///
/// `where_clause` is the fragment after `WHERE`, including the trailing semicolon
/// (e.g. `"\"name\" = ? and \"deleted_at\" is null;"`).
/// `where_binds` are the corresponding parameter values.
pub fn build(
  b: PatchBuilder,
  table: String,
  where_clause: String,
  where_binds: List(sqlight.Value),
) -> #(String, List(sqlight.Value)) {
  let set_sql = string.join(list.reverse(b.set_parts), ", ")
  let sql =
    "update \""
    <> table
    <> "\" set "
    <> set_sql
    <> " where "
    <> where_clause
  let binds = list.flatten([list.reverse(b.binds), where_binds])
  #(sql, binds)
}
