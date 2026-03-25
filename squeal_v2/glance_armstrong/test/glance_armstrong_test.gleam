import gleam/io
import birdie
import glance
import gleeunit
import glance_armstrong

pub fn main() {
  gleeunit.main()
}

pub fn simple_warning_test() {
  glance_armstrong.format_source_diagnostic("fn foo(x: Int) -> Int {
    x + 1
  }", glance.Span(0, 0), "warning")
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
  glance_armstrong.format_reference_line(1, source, "Here is some extra test on this")
  |> log
  |> birdie.snap(title: "glance_armstrong format reference line")
}

pub fn format_diagnostic_without_span_test() {
  glance_armstrong.format_diagnostic_without_span("Here is some extra test on this")
  |> log
  |> birdie.snap(title: "glance_armstrong diagnostic without span")
}

fn log (a: String) -> String {
  io.println("\n")
  io.print(a)
  io.println("\n")
  a
}