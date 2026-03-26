import argv
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import generators/api/api as api_generator
import generators/migration/migration as migration_generator
import generators/skeleton as skeleton_generator
import schema_definition/schema_definition as schema_definition
import simplifile

pub fn main() -> Nil {
  glint.run(app(), argv.load().arguments)
}

/// Backwards-compatible entry when the module is run as `gleam run skeleton …`.
pub fn main_as_skeleton_module() -> Nil {
  let args = argv.load().arguments
  case args {
    ["--help"] | ["-h"] -> glint.run(app(), args)
    [path] -> run_generate(path)
    _ -> glint.run(app(), args)
  }
}

/// Read [schema_path], emit `skeleton.gleam`, `migration.gleam`, and `api.gleam`
/// under the sibling `*_db` directory (e.g. `src/.../fruit_schema` → `src/.../fruit_db/`).
pub fn run_generate(schema_path: String) -> Nil {
  case generate_from_schema_path(schema_path) {
    Ok(_) -> Nil
    Error(msg) -> {
      io.println(msg)
      halt(1)
    }
  }
}

fn generate_from_schema_path(user_path: String) -> Result(Nil, String) {
  use schema_file <- result.try(resolve_schema_file(user_path))
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
  let schema_import = gleam_import_path(schema_file)
  let out_dir = output_db_directory(schema_file)
  let migration_tag = db_import_path(schema_import) <> "/migration"
  use _ <- result.try(
    simplifile.create_directory_all(out_dir)
    |> result.map_error(fn(e) {
      "failed to create " <> out_dir <> ": " <> simplifile.describe_error(e)
    }),
  )
  let skeleton_out = out_dir <> "/skeleton.gleam"
  let migration_out = out_dir <> "/migration.gleam"
  let api_out = out_dir <> "/api.gleam"
  let skeleton_text = skeleton_generator.generate(schema_import, def)
  let api_text = api_generator.generate_api(schema_import, def)
  use _ <- result.try(write_file(skeleton_out, skeleton_text))
  use _ <- result.try(write_file(api_out, api_text))
  io.println("wrote " <> skeleton_out)
  io.println("wrote " <> api_out)
  case list.length(def.entities) {
    1 -> {
      let migration_text =
        migration_generator.generate_pragma_migration_module(def, migration_tag)
      use _ <- result.try(write_file(migration_out, migration_text))
      io.println("wrote " <> migration_out)
      Ok(Nil)
    }
    _ -> {
      io.println(
        "skipped "
        <> migration_out
        <> " (pragma migration codegen is single-entity only; keep a hand-written module like case_studies/hippo_db/migration.gleam)",
      )
      Ok(Nil)
    }
  }
}

fn write_file(path: String, contents: String) -> Result(Nil, String) {
  simplifile.write(to: path, contents:)
  |> result.map_error(fn(e) {
    "failed to write " <> path <> ": " <> simplifile.describe_error(e)
  })
}

fn app() -> glint.Glint(Nil) {
  glint.new()
  |> glint.with_name("squeal_v2")
  |> glint.global_help(
    "Generate squeal DB modules (skeleton, migration, api) from a schema module path.",
  )
  |> glint.add(at: [], do: root_command())
}

fn resolve_schema_file(path: String) -> Result(String, String) {
  let trimmed = string.trim(path)
  let with_ext = ensure_gleam_extension(trimmed)
  case string.starts_with(with_ext, "/") || string.starts_with(with_ext, "src/") {
    True -> Ok(with_ext)
    False -> Ok("src/" <> with_ext)
  }
}

fn ensure_gleam_extension(path: String) -> String {
  case string.ends_with(path, ".gleam") {
    True -> path
    False -> path <> ".gleam"
  }
}

fn gleam_import_path(schema_file: String) -> String {
  let without_ext = case string.ends_with(schema_file, ".gleam") {
    True -> string.drop_end(schema_file, string.length(".gleam"))
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

fn db_import_path(schema_import: String) -> String {
  let parts = string.split(schema_import, "/")
  let assert Ok(last) = list.last(parts)
  let base = case string.ends_with(last, "_schema") {
    True -> string.drop_end(last, string.length("_schema")) <> "_db"
    False -> last <> "_db"
  }
  let n = list.length(parts)
  case n <= 1 {
    True -> base
    False -> string.join(list.append(list.take(parts, n - 1), [base]), with: "/")
  }
}

fn output_db_directory(schema_file: String) -> String {
  let parts = string.split(schema_file, "/")
  let assert Ok(file) = list.last(parts)
  let stem = case string.ends_with(file, ".gleam") {
    True -> string.drop_end(file, string.length(".gleam"))
    False -> file
  }
  let dir_name = case string.ends_with(stem, "_schema") {
    True -> string.drop_end(stem, string.length("_schema")) <> "_db"
    False -> stem <> "_db"
  }
  let dir_len = list.length(parts) - 1
  case dir_len <= 0 {
    True -> dir_name
    False -> string.join(list.append(list.take(parts, dir_len), [dir_name]), with: "/")
  }
}

fn root_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Emit skeleton.gleam, migration.gleam, and api.gleam under the sibling *_db directory.",
  )
  use <- glint.unnamed_args(glint.EqArgs(1))
  use _n, unnamed, _f <- glint.command()
  let assert [path] = unnamed
  run_generate(path)
  Nil
}

@external(erlang, "erlang", "halt")
@external(javascript, "node:process", "exit")
fn halt(status: Int) -> Nil
