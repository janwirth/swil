//// Two-line terminal diagnostics: `line | source` then padded `^` + message.
//// Used by [`schema_definition.format_parse_error`](schema_definition.html#format_parse_error).

import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// `line | full line text` then a second line with spaces, carets, and `message`.
pub fn format_source_diagnostic(
  source: String,
  span: glance.Span,
  message: String,
) -> String {
  let glance.Span(raw_start, raw_end) = span
  let start_byte = int.max(0, raw_start)
  let end_byte = int.max(start_byte, raw_end)
  let indexed = source_indexed_lines(source)
  case find_line_for_byte(indexed, start_byte) {
    Error(Nil) -> format_diagnostic_without_span(message)
    Ok(#(line_no, line_start, line_text)) -> {
      let col = start_byte - line_start
      let line_blen = string.byte_size(line_text)
      let col_clamped = int.min(col, line_blen)
      let max_w = int.max(1, line_blen - col_clamped)
      let raw_w = end_byte - start_byte
      let #(caret_col, caret_width) = case generic_param_highlight_bytes(line_text) {
        Some(#(c, w)) ->
          case string.contains(message, "generic parameters") {
            True -> #(c, w)
            False -> #(
              col_clamped,
              int.max(1, int.min(int.min(raw_w, max_w), 28)),
            )
          }
        None -> #(
          col_clamped,
          int.max(1, int.min(int.min(raw_w, max_w), 28)),
        )
      }
      render_gutter_block(line_no, line_text, caret_col, caret_width, message)
    }
  }
}

/// Same visual style when no byte span exists (unknown or out-of-range).
pub fn format_diagnostic_without_span(message: String) -> String {
  let gutter = "   — | "
  let code_line = gutter <> "<no source location>"
  let pad = string.byte_size(gutter)
  let pointer =
    string.repeat(" ", times: pad) <> "^ " <> message
  code_line <> "\n" <> pointer
}

pub fn format_glance_parse_error(source: String, error: glance.Error) -> String {
  case error {
    glance.UnexpectedEndOfInput -> format_unexpected_eof_diagnostic(source)
    glance.UnexpectedToken(_token, pos) ->
      format_source_diagnostic(
        source,
        glance.Span(pos.byte_offset, pos.byte_offset + 1),
        "unexpected token",
      )
  }
}

fn format_unexpected_eof_diagnostic(source: String) -> String {
  let indexed = source_indexed_lines(source)
  case list.last(indexed) {
    Error(Nil) ->
      format_diagnostic_without_span(
        "unexpected end of input when parsing Gleam (empty file)",
      )
    Ok(#(line_no, _line_start, line_text)) -> {
      let line_blen = string.byte_size(line_text)
      let caret_col = int.max(0, line_blen)
      render_gutter_block(line_no, line_text, caret_col, 1, "unexpected end of input when parsing Gleam")
    }
  }
}

/// Same gutter as [`format_source_diagnostic`](#format_source_diagnostic), for an arbitrary line (e.g. extra notes).
pub fn format_reference_line(
  line_no: Int,
  line_text: String,
  message: String,
) -> String {
  let w =
    int.min(40, int.max(1, string.byte_size(line_text)))
  render_gutter_block(line_no, line_text, 0, w, message)
}

fn render_gutter_block(
  line_no: Int,
  line_text: String,
  caret_col: Int,
  caret_width: Int,
  message: String,
) -> String {
  let num = string.pad_start(int.to_string(line_no), to: 4, with: " ")
  let gutter = num <> " | "
  let code_line = gutter <> line_text
  let pad_width = string.byte_size(gutter) + caret_col
  let spaces = string.repeat(" ", times: pad_width)
  let carets = string.repeat("^", times: int.max(1, caret_width))
  let pointer = spaces <> carets <> " " <> message
  code_line <> "\n" <> pointer
}

fn generic_param_highlight_bytes(line_text: String) -> Option(#(Int, Int)) {
  case string.split(line_text, "(") {
    [before, after_open, ..] -> {
      let open_col = string.byte_size(before)
      case string.split(after_open, ")") {
        [inside, ..] -> {
          let w = 1 + string.byte_size(inside) + 1
          Some(#(open_col, int.max(1, w)))
        }
        _ -> None
      }
    }
    _ -> None
  }
}

fn source_lines_with_byte_starts(source: String) -> List(#(Int, String)) {
  let parts = string.split(source, "\n")
  let #(rows_rev, _) =
    list.fold(over: parts, from: #([], 0), with: fn(state, line_text) {
      let #(acc_rows, byte_offset) = state
      #(
        [#(byte_offset, line_text), ..acc_rows],
        byte_offset + string.byte_size(line_text) + 1,
      )
    })
  list.reverse(rows_rev)
}

fn source_indexed_lines(source: String) -> List(#(Int, Int, String)) {
  let raw = source_lines_with_byte_starts(source)
  list.index_map(raw, fn(pair, i) {
    let #(byte_start, text) = pair
    #(i + 1, byte_start, text)
  })
}

fn find_line_for_byte(
  indexed: List(#(Int, Int, String)),
  byte_pos: Int,
) -> Result(#(Int, Int, String), Nil) {
  let on_line = fn(row: #(Int, Int, String)) -> Bool {
    let #(_no, start, text) = row
    let after_start = byte_pos >= start
    let line_past = start + string.byte_size(text)
    let before_end = byte_pos <= line_past
    after_start && before_end
  }
  case list.filter(indexed, on_line) {
    [row, ..] -> Ok(row)
    [] ->
      case list.last(indexed) {
        Ok(row) -> Ok(row)
        Error(Nil) -> Error(Nil)
      }
  }
}
