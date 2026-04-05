import glance
import glance_armstrong
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Render with [`format_parse_error`](#format_parse_error) / [`schema_diagnostics`](schema_diagnostics.html).
pub type ParseError {
  GlanceError(glance.Error)
  /// Optional primary span, related single-line notes (constructor, etc.), then message.
  UnsupportedSchema(
    span: Option(glance.Span),
    related: List(#(glance.Span, String)),
    message: String,
  )
}

/// Appended to errors about disallowed public [`glance.Function`](glance.Function) names.
pub fn hint_public_function_prefixes() -> String {
  "Hint: public functions in a swil schema module must use prefix `query_` (query pipeline spec) or `predicate_` (BooleanFilter helper)."
}

/// Appended when a public custom type is neither a recognised suffix bucket nor a valid entity.
pub fn hint_public_type_suffixes_or_entity() -> String {
  "Hint: public types must end with `Scalar`, `Identities`, `Relationships`, or `Attributes`, or be a valid entity (one record variant named like the type with a labelled `identities: *Identities` field)."
}

/// Turn a [`ParseError`](#ParseError) into text using [`schema_diagnostics`](schema_diagnostics.html) (line + caret layout).
pub fn format_parse_error(source: String, error: ParseError) -> String {
  case error {
    GlanceError(e) -> glance_armstrong.format_glance_parse_error(source, e)
    UnsupportedSchema(None, related, message) -> {
      let head = glance_armstrong.format_diagnostic_without_span(message)
      head <> format_related_diagnostics(source, related)
    }
    UnsupportedSchema(Some(span), related, message) -> {
      let primary = format_primary_schema_diagnostic(source, span, message)
      primary <> format_related_diagnostics(source, related)
    }
  }
}

fn format_related_diagnostics(
  source: String,
  related: List(#(glance.Span, String)),
) -> String {
  case related {
    [] -> ""
    pairs ->
      list.map(pairs, fn(pair) {
        let #(span, note) = pair
        "\n" <> glance_armstrong.format_source_diagnostic(source, span, note)
      })
      |> string.join("")
  }
}

fn format_primary_schema_diagnostic(
  source: String,
  span: glance.Span,
  message: String,
) -> String {
  case span_covers_single_line(source, span) {
    True -> glance_armstrong.format_source_diagnostic(source, span, message)
    False -> format_multiline_source_diagnostic(source, span, message)
  }
}

fn span_covers_single_line(source: String, span: glance.Span) -> Bool {
  let glance.Span(raw_start, raw_end) = span
  let start_byte = int.max(0, raw_start)
  let end_byte = int.max(start_byte, raw_end)
  let indexed = source_indexed_lines(source)
  case find_line_for_byte(indexed, start_byte) {
    Error(Nil) -> True
    Ok(#(a, _, _)) ->
      case find_line_for_byte(indexed, int.max(start_byte, end_byte - 1)) {
        Error(Nil) -> True
        Ok(#(b, _, _)) -> a == b
      }
  }
}

fn format_multiline_source_diagnostic(
  source: String,
  span: glance.Span,
  message: String,
) -> String {
  let glance.Span(raw_start, raw_end) = span
  let start_byte = int.max(0, raw_start)
  let end_byte = int.max(start_byte, raw_end)
  let indexed = source_indexed_lines(source)
  let overlapping =
    list.filter(indexed, fn(row) {
      let #(_no, line_start, text) = row
      let line_end = line_start + string.byte_size(text)
      line_end > start_byte && line_start < end_byte
    })
  case overlapping {
    [] -> glance_armstrong.format_diagnostic_without_span(message)
    rows -> {
      let gutters = format_overlapping_lines(rows, start_byte, end_byte, "")
      gutters <> "\n" <> message
    }
  }
}

fn format_overlapping_lines(
  rows: List(#(Int, Int, String)),
  span_start: Int,
  span_end: Int,
  message: String,
) -> String {
  case rows {
    [] -> ""
    [first, ..rest] -> {
      let #(ln, ls, lt) = first
      let first_text =
        render_line_intersection(ln, ls, lt, span_start, span_end, message)
      list.fold(over: rest, from: first_text, with: fn(acc, row) {
        let #(ln2, ls2, lt2) = row
        acc
        <> "\n"
        <> render_line_intersection(ln2, ls2, lt2, span_start, span_end, "")
      })
    }
  }
}

fn render_line_intersection(
  line_no: Int,
  line_start: Int,
  line_text: String,
  span_start: Int,
  span_end: Int,
  message: String,
) -> String {
  let line_end = line_start + string.byte_size(line_text)
  let rel_start = int.max(span_start, line_start)
  let rel_end = int.min(span_end, line_end)
  let col = rel_start - line_start
  let line_blen = string.byte_size(line_text)
  let col_clamped = int.min(col, line_blen)
  let width = int.max(1, rel_end - rel_start)
  let max_w = int.max(1, line_blen - col_clamped)
  let caret_width = int.min(width, max_w)
  render_gutter_block(line_no, line_text, col_clamped, caret_width, message)
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
  let pad_width = gutter_display_width(gutter) + caret_col
  let spaces = string.repeat(" ", times: pad_width)
  let carets = string.repeat("^", times: int.max(1, caret_width))
  let pointer = spaces <> carets <> " " <> message
  code_line <> "\n" <> pointer
}

fn gutter_display_width(gutter: String) -> Int {
  string.length(gutter)
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

/// Byte span covering the first occurrence of `TypeName` in `TypeName(` inside a custom type body.
pub fn span_for_record_constructor_name(
  source: String,
  type_name: String,
  within: glance.Span,
) -> Option(glance.Span) {
  let glance.Span(t_start, t_end) = within
  let needle = type_name <> "("
  case list.find_map(source_indexed_lines(source), fn(row) {
    let #(_no, line_start, line_text) = row
    let line_end = line_start + string.byte_size(line_text)
    case line_end <= t_start || line_start >= t_end {
      True -> Error(Nil)
      False ->
        case string.split(line_text, needle) {
          [before, _, ..] -> {
            let col = string.byte_size(before)
            let abs_start = line_start + col
            let abs_end = abs_start + string.byte_size(type_name)
            Ok(glance.Span(abs_start, abs_end))
          }
          _ -> Error(Nil)
        }
    }
  }) {
    Ok(sp) -> Some(sp)
    Error(_) -> None
  }
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
