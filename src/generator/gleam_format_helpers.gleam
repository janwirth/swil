import gleam/list
import gleam/string

/// Line width for breaking import lists; matches `gleam format` (not strict ASCII 80).
pub const import_list_max_col = 80

/// Comma-separated lines with trailing commas, like `gleam format` on import groups.
pub fn comma_wrap_lines(
  indent: String,
  items: List(String),
  max_col: Int,
) -> String {
  case items {
    [] -> ""
    [first, ..rest] -> wrap_loop(indent, rest, first, [], max_col)
  }
}

fn wrap_loop(
  indent: String,
  items: List(String),
  current: String,
  lines: List(String),
  max_col: Int,
) -> String {
  case items {
    [] ->
      list.reverse([string.concat([indent, current, ","]), ..lines])
      |> string.join("\n")
    [x, ..xs] -> {
      let candidate = string.concat([current, ", ", x])
      case string.length(string.concat([indent, candidate])) > max_col {
        True ->
          wrap_loop(
            indent,
            xs,
            x,
            [string.concat([indent, current, ","]), ..lines],
            max_col,
          )
        False -> wrap_loop(indent, xs, candidate, lines, max_col)
      }
    }
  }
}
