import glance_armstrong
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import schema_definition/schema_definition

fn nth_line(source: String, line_no: Int) -> String {
  let lines = string.split(source, "\n")
  case list.drop(from: lines, up_to: line_no - 1) {
    [row, ..] -> row
    [] -> ""
  }
}

fn print_source_reference_line(
  source: String,
  line_no: Int,
  message: String,
) -> Nil {
  io.println(glance_armstrong.format_reference_line(
    line_no,
    nth_line(source, line_no),
    message,
  ))
  io.println("")
}

fn print_entity_constructor_hint() -> Nil {
  io.println(
    glance_armstrong.format_diagnostic_without_span_with_tips(
      "Record variant must be named like the type.",
      [
        "Reuse the type name for the constructor (e.g. `pub type Tab { Tab(...) }`).",
      ],
    ),
  )
  io.println("")
}

pub fn entity_error_suggests_constructor_hint(
  err: schema_definition.ParseError,
) -> Bool {
  case err {
    schema_definition.GlanceError(_) -> False
    schema_definition.UnsupportedSchema(_, message) ->
      string.contains(
        does: message,
        contain: "must use a variant constructor named",
      )
      || string.contains(
        does: message,
        contain: "must use only labelled fields on its record variant",
      )
      || string.contains(
        does: message,
        contain: "has a record variant named like the type but no `identities` field",
      )
  }
}

fn print_query_spec_help() -> Nil {
  io.println(
    "  • Public query specs must end as `query(...) |> shape(...) |> filter(...) |> order(...)` and type every parameter.",
  )
  io.println("  • For example:")
  io.println("")
  io.println(
    "    pub fn query_rows_matching_status(row: Row, magic: dsl.MagicFields, want: StatusScalar) {",
  )
  io.println(
    "      query(row) |> shape(row) |> filter(row.status == want) |> order(row.id, dsl.Asc)",
  )
  io.println("    }")
  io.println("")
}

fn print_parse_error_diagnostic(
  source: String,
  err: schema_definition.ParseError,
) -> Nil {
  case err {
    schema_definition.GlanceError(e) ->
      io.println(glance_armstrong.format_glance_parse_error(source, e))
    schema_definition.UnsupportedSchema(Some(span), message) ->
      io.println(glance_armstrong.format_source_diagnostic(
        source,
        span,
        message,
      ))
    schema_definition.UnsupportedSchema(None, message) ->
      io.println(glance_armstrong.format_diagnostic_without_span(message))
  }
}

/// Prints a titled banner, the primary diagnostic, optional entity hint, an extra
/// reference line (e.g. a known hotspot in a fixture), and query-spec help.
pub fn print_schema_rejection_report(
  banner_title title: String,
  file_path path: String,
  source src: String,
  parse_err err: schema_definition.ParseError,
  follow_up_reference extra: Option(#(Int, String)),
) -> Nil {
  io.println("\n========== " <> title <> " ==========")
  io.println("file: " <> path)
  io.println("")
  print_parse_error_diagnostic(src, err)
  io.println("")
  case entity_error_suggests_constructor_hint(err) {
    True -> print_entity_constructor_hint()
    False -> Nil
  }
  case extra {
    Some(#(line_no, message)) ->
      print_source_reference_line(src, line_no, message)
    None -> Nil
  }
  print_query_spec_help()
  io.println("========================================================\n")
}
