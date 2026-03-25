import diff.{type DiffLine, New, Old, Shared}
import gleam/int
import gleam/list
import gleam/string

pub fn assert_diff(expected: String, actual: String) -> Nil {
  case expected == actual {
    True -> Nil
    False -> {
      let lines = diff.histogram(expected, actual)
      let report = format_diff_report(lines)
      panic as string.concat([
        "\nassert_diff: expected and actual differ\n\n",
        report,
      ])
    }
  }
}

fn format_diff_report(lines: List(DiffLine)) -> String {
  lines
  |> list.filter(fn(line) {
    case line.kind {
      Shared -> False
      Old | New -> True
    }
  })
  |> list.map(format_diff_line)
  |> string.join(with: "\n")
}

fn format_diff_line(line: DiffLine) -> String {
  case line.kind {
    Old -> "- " <> int.to_string(line.number) <> "\t" <> line.line
    New -> "+ " <> int.to_string(line.number) <> "\t" <> line.line
    Shared -> ""
  }
}
