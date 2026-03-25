import birdie
import glance
import glance_armstrong
import gleam/io
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn simple_warning_test() {
  glance_armstrong.format_source_diagnostic(
    "fn foo(x: Int) -> Int {
    x + 1
  }",
    glance.Span(0, 0),
    "warning",
  )
  |> log
  |> birdie.snap(title: "glance_armstrong simple warning diagnostic")
}

pub fn simple_parse_error_test() {
  let source = "fn foo(x: Int) -> Int {"
  let assert Error(err) = glance.module(source)
  glance_armstrong.format_glance_parse_error(source, err)
  |> log
  |> birdie.snap(title: "glance_armstrong simple parse error")
}

pub fn format_reference_line_test() {
  let source = "pub type Foo {}"
  let assert Ok(_) = glance.module(source)
  glance_armstrong.format_reference_line(
    1,
    source,
    "Here is some extra test on this",
  )
  |> log
  |> birdie.snap(title: "glance_armstrong format reference line")
}

pub fn format_diagnostic_without_span_test() {
  glance_armstrong.format_diagnostic_without_span(
    "Here is some extra test on this",
  )
  |> log
  |> birdie.snap(title: "glance_armstrong diagnostic without span")
}

pub fn source_diagnostic_with_tips_test() {
  let line = "pub fn all_tabs() -> List(Tab) {"
  let source = "\n\n" <> line
  let start = string.byte_size("\n\n")
  let span = glance.Span(start, start + string.byte_size(line))
  let message =
    "public function must return a Query (annotation or trailing Query(...))"
  let tips = [
    "Public query specs must return `Query(...)` (or use a `-> Query` return annotation) and type every parameter.",
    "For example:\n\npub fn rows_matching_status(row: Row, want: StatusScalar) {\n  Query(shape: option.None, filter: option.None, order: option.None)\n}",
  ]
  glance_armstrong.format_source_diagnostic_with_tips(
    source,
    span,
    message,
    tips,
  )
  |> log
  |> birdie.snap(title: "glance_armstrong source diagnostic with tips")
}

pub fn diagnostic_without_span_with_tips_test() {
  glance_armstrong.format_diagnostic_without_span_with_tips(
    "could not load module",
    ["Check that the path exists.", "Try `gleam deps download`."],
  )
  |> log
  |> birdie.snap(title: "glance_armstrong diagnostic without span with tips")
}

fn log(a: String) -> String {
  io.println("\n")
  io.print(a)
  io.println("\n")
  a
}
