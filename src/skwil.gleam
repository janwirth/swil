import argv
import generators/api/api as api_generator
import generators/migration/migration as migration_generator
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import schema_definition/parser as schema_parser
import simplifile

pub fn main() -> Nil {
  glint.run(app(), argv.load().arguments)
}

/// Read [schema_path], emit `migration.gleam`, `row.gleam`, `get.gleam`,
/// `upsert.gleam`, `delete.gleam`, `query.gleam`, and `api.gleam` under the sibling `*_db` directory.
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
    schema_parser.parse_module(src)
    |> result.map_error(fn(e) {
      "In " <> schema_file <> ":\n" <> schema_parser.format_parse_error(src, e)
    }),
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
  let migration_out = out_dir <> "/migration.gleam"
  let row_out = out_dir <> "/row.gleam"
  let get_out = out_dir <> "/get.gleam"
  let upsert_out = out_dir <> "/upsert.gleam"
  let delete_out = out_dir <> "/delete.gleam"
  let query_out = out_dir <> "/query.gleam"
  let api_out = out_dir <> "/api.gleam"
  use api_outputs <- result.try(api_generator.generate_api_db_outputs(
    schema_import,
    def,
  ))
  use _ <- result.try(write_file(row_out, api_outputs.row))
  use _ <- result.try(write_file(get_out, api_outputs.get))
  use _ <- result.try(write_file(upsert_out, api_outputs.upsert))
  use _ <- result.try(write_file(delete_out, api_outputs.delete))
  use _ <- result.try(write_file(query_out, api_outputs.query))
  use _ <- result.try(write_file(api_out, api_outputs.api))
  use migration_text <- result.try(
    migration_generator.generate_pragma_migration_module_with_junctions(
      def,
      migration_tag,
    ),
  )
  use _ <- result.try(write_file(migration_out, migration_text))
  io.println("wrote " <> row_out)
  io.println("wrote " <> get_out)
  io.println("wrote " <> upsert_out)
  io.println("wrote " <> delete_out)
  io.println("wrote " <> query_out)
  io.println("wrote " <> api_out)
  io.println("wrote " <> migration_out)
  Ok(Nil)
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
    "Generate squeal DB modules (migration, api) from a schema module path.",
  )
  |> glint.add(at: [], do: root_command())
}

fn resolve_schema_file(path: String) -> Result(String, String) {
  let trimmed = string.trim(path)
  let with_ext = ensure_gleam_extension(trimmed)
  case
    string.starts_with(with_ext, "/") || string.starts_with(with_ext, "src/")
  {
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
    False ->
      string.join(list.append(list.take(parts, n - 1), [base]), with: "/")
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
    False ->
      string.join(list.append(list.take(parts, dir_len), [dir_name]), with: "/")
  }
}

fn root_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Emit migration, row, get, upsert, delete, query, and api modules under the sibling *_db directory.",
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
