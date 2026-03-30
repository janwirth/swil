import gleam/int
import gleam/result
import gleam/string
import gleam/time/timestamp
import shellout
import simplifile

/// Writes [source] to a unique `.gleam` path under `/tmp`, runs
/// `gleam format --stdin` with that file as stdin (same as `gleam format --stdin < path`),
/// returns stdout, then deletes the temp file.
pub fn format_generated_source(source: String) -> Result(String, String) {
  let #(sec, nano) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds
  let path =
    "/tmp/skwil_fmt_"
    <> int.to_string(sec)
    <> "_"
    <> int.to_string(nano)
    <> "_"
    <> int.to_string(string.byte_size(source))
    <> ".gleam"
  use _ <- result.try(
    simplifile.write(path, source)
    |> result.map_error(fn(e) {
      "gleam format temp write failed for "
      <> path
      <> ": "
      <> simplifile.describe_error(e)
    }),
  )
  use formatted <- result.try(
    shellout.command(
      run: "sh",
      with: ["-c", "gleam format --stdin < " <> path],
      in: ".",
      opt: [],
    )
    |> result.map_error(fn(detail) {
      let #(status, msg) = detail
      "gleam format --stdin failed (" <> int.to_string(status) <> "): " <> msg
    }),
  )
  let _ = simplifile.delete(path)
  Ok(formatted)
}
