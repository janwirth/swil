// make her a code generator
// it reads a full gleam module based on type 

import generator/migration as migration_generator
import gleeunit
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
    #(cat_v1, "test/experiments/migrations/v1.gleam"),
    #(cat_v2, "test/experiments/migrations/v2.gleam"),
    #(cat_v3, "test/experiments/migrations/v3.gleam"),
  ]
}

fn assert_fixtures(fixtures: List(#(String, String))) {
  case fixtures {
    [#(module, path), ..rest] -> {
      let assert Ok(expected) = simplifile.read(path)
      assert migration_generator.generate(module) == expected
      assert_fixtures(rest)
    }
    [] -> Nil
  }
}

pub fn generate_migration_fixtures_test() {
  // Intentionally excludes src/help/migrate.gleam from fixture assertions.
  assert_fixtures(module_paths())
}

pub fn generate_matches_cat_db_migrate_test() {
  let assert Ok(module) = simplifile.read("src/cat_schema.gleam")
  let actual = migration_generator.generate(module)
  let assert Ok(expected) = simplifile.read("src/cat_db/migrate.gleam")
  assert actual == expected
}
