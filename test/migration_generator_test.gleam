// make her a code generator
// it reads a full gleam module based on type 

import gleeunit
import gleam/list
import gleam/string
import gen/migration_generator
import simplifile

pub const cat_v1 = "

pub type Cat {
    Cat(name: String)
}
"
pub const cat_v2 = "
pub type Cat {
    Cat(name: String, age: Int)
}
"

pub const cat_v3 = "
pub type Cat {
    Cat(name: String, age: Int, gender: Option(String))
}
"

pub fn main() -> Nil {
  gleeunit.main()
}

fn module_paths() -> List(#(String, String)) {
  [
    #(cat_v1, "test/migrations/v1.gleam"),
    #(cat_v2, "test/migrations/v2.gleam"),
    #(cat_v3, "test/migrations/v3.gleam"),
  ]
}

fn resolve_path(module: String, entries: List(#(String, String))) -> String {
  case entries {
    [#(known_module, path), ..rest] ->
      case module == known_module {
        True -> path
        False -> resolve_path(module, rest)
      }
    [] -> "src/gen/migration_help.gleam"
  }
}

fn generate(module: String) -> String {
  let version = infer_version(module)
  migration_generator.generate(module, version)
}

fn infer_version(module: String) -> String {
  let path = resolve_path(module, module_paths())
  case string.split(path, "/") |> list.reverse() {
    [filename, ..] ->
      case string.split(filename, ".gleam") {
        [version, ..] -> version
        _ -> "shared"
      }
    _ -> "shared"
  }
}

fn assert_fixtures(fixtures: List(#(String, String))) {
  case fixtures {
    [#(module, path), ..rest] -> {
      let assert Ok(expected) = simplifile.read(path)
      assert generate(module) == expected
      assert_fixtures(rest)
    }
    [] -> Nil
  }
}

pub fn generate_migration_fixtures_test() {
  // Intentionally excludes src/gen/migration_help.gleam from fixture assertions.
  assert_fixtures(module_paths())
}