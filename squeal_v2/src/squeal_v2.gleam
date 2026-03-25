import argv
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import schema_definition
import simplifile
import skeleton_generator

pub fn main() -> Nil {
  glint.run(app(), argv.load().arguments)
}

/// Entry for `gleam run skeleton …` where the first argv is the schema path.
pub fn main_as_skeleton_module() -> Nil {
  let args = argv.load().arguments
  case args {
    ["--help"] | ["-h"] -> glint.run(app(), args)
    [path] -> run_skeleton(path)
    _ -> glint.run(app(), args)
  }
}

/// Generate `*_db_skeleton.gleam` next to the schema module at [schema_path].
/// [schema_path] may omit the `.gleam` suffix.
pub fn run_skeleton(schema_path: String) -> Nil {
  case skeleton_from_schema_path(schema_path) {
    Ok(_) -> Nil
    Error(msg) -> {
      io.println(msg)
      halt(1)
    }
  }
}

fn app() -> glint.Glint(Nil) {
  glint.new()
  |> glint.with_name("squeal_v2")
  |> glint.global_help(
    "Generate Gleam DB skeleton modules from squeal schema modules.",
  )
  |> glint.add(at: [], do: root_command())
  |> glint.add(at: ["skeleton"], do: skeleton_command())
}

fn skeleton_from_schema_path(schema_path: String) -> Result(Nil, String) {
  let schema_file = ensure_gleam_extension(string.trim(schema_path))
  use src <- result.try(
    simplifile.read(schema_file)
    |> result.map_error(fn(e) {
      "failed to read " <> schema_file <> ": " <> simplifile.describe_error(e)
    }),
  )
  use def <- result.try(
    schema_definition.parse_module(src)
    |> result.map_error(schema_definition.format_parse_error(src, _)),
  )
  let import_path = gleam_import_path(schema_file)
  let out_file = output_skeleton_path(schema_file)
  let out = skeleton_generator.generate(import_path, def)
  use _ <- result.try(
    simplifile.write(to: out_file, contents: out)
    |> result.map_error(fn(e) {
      "failed to write " <> out_file <> ": " <> simplifile.describe_error(e)
    }),
  )
  io.println("wrote " <> out_file)
  Ok(Nil)
}

fn ensure_gleam_extension(path: String) -> String {
  case string.ends_with(path, ".gleam") {
    True -> path
    False -> path <> ".gleam"
  }
}

fn gleam_import_path(schema_file: String) -> String {
  let without_ext = case string.ends_with(schema_file, ".gleam") {
    True ->
      string.drop_end(schema_file, string.length(".gleam"))
    False -> schema_file
  }
  case string.starts_with(without_ext, "src/") {
    True -> string.drop_start(without_ext, string.length("src/"))
    False -> {
      let parts = string.split(without_ext, "/src/")
      case list.length(parts) > 1 {
        True -> {
          let assert Ok(after_src) = list.last(parts)
          after_src
        }
        False -> without_ext
      }
    }
  }
}

fn output_skeleton_path(schema_file: String) -> String {
  let parts = string.split(schema_file, "/")
  let assert Ok(base) = list.last(parts)
  let stem = case string.ends_with(base, ".gleam") {
    True -> string.drop_end(base, string.length(".gleam"))
    False -> base
  }
  let out_stem = case string.ends_with(stem, "_schema") {
    True ->
      string.drop_end(stem, string.length("_schema")) <> "_db_skeleton"
    False -> stem <> "_db_skeleton"
  }
  let dir_len = list.length(parts) - 1
  case dir_len <= 0 {
    True -> out_stem <> ".gleam"
    False -> {
      let dir = string.join(list.take(parts, dir_len), with: "/")
      dir <> "/" <> out_stem <> ".gleam"
    }
  }
}

fn root_command() -> glint.Command(Nil) {
  use <- glint.command_help("Show usage when no subcommand is given.")
  use <- glint.unnamed_args(glint.EqArgs(0))
  use _n, _u, _f <- glint.command()
  io.println(
    "Usage: gleam run -- skeleton <path-to-schema>\n"
    <> "   or: gleam run skeleton <path-to-schema>",
  )
  Nil
}

fn skeleton_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Emit a *_db_skeleton.gleam module beside the schema source file.",
  )
  use <- glint.unnamed_args(glint.EqArgs(1))
  use _n, unnamed, _f <- glint.command()
  let assert [path] = unnamed
  run_skeleton(path)
  Nil
}

@external(erlang, "erlang", "halt")
@external(javascript, "node:process", "exit")
fn halt(status: Int) -> Nil
