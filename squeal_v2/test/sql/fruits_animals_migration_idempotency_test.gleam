// Drives the hand-written example migration modules (blueprints for codegen): exclusive
// fruit vs animal versions, idempotent replays, and switching back and forth.
import assert_diff.{assert_diff}
import case_studies/fruit_db/migration as example_migration_fruit
import case_studies/example_migration_animal as example_migration_animal
import generators/migration/migration
import schema_definition/schema_definition as schema_definition
import simplifile
import sqlight

const schema2 = "
import gleam/option
pub type Animal {
    Animal(
        name: option.Option(String),
        species: option.Option(String),
        age: option.Option(Int),
        color: option.Option(String),
        identities: AnimalIdentities,
    )
}
pub type AnimalIdentities {
    ByName(name: String)
}
"

pub fn fruit_pragma_test() {
  let assert Ok(schema1) =
    simplifile.read("src/case_studies/fruit_schema.gleam")
  let assert Ok(fruit_expected) =
    simplifile.read("src/case_studies/fruit_db/migration.gleam")
  let assert Ok(fruit_def) = schema_definition.parse_module(schema1)
  let fruit_gleam =
    migration.generate_pragma_migration_module(
      fruit_def,
      "case_studies/fruit_db/migration",
    )
  // let written_output = simplifile.write("src/case_studies/fruit_db/migration.gleam", fruit_gleam)
  assert_diff(fruit_expected, fruit_gleam)
}

pub fn animal_pragma_test() {
  let assert Ok(animal_expected) =
    simplifile.read("src/case_studies/example_migration_animal.gleam")
  let assert Ok(animal_def) = schema_definition.parse_module(schema2)
  let animal_gleam =
    migration.generate_pragma_migration_module(
      animal_def,
      "case_studies/example_migration_animal",
    )
  // let written_output = simplifile.write("src/case_studies/example_migration_animal.gleam", animal_gleam)
  assert_diff(animal_expected, animal_gleam)
}

pub fn idempotent_migration_test() {
  let assert Ok(conn) = sqlight.open(":memory:")

  let assert Ok(Nil) = example_migration_fruit.migration(conn)
  let assert Ok(Nil) = example_migration_fruit.migration(conn)

  let assert Ok(Nil) = example_migration_animal.migration(conn)
  let assert Ok(Nil) = example_migration_animal.migration(conn)

  let assert Ok(Nil) = example_migration_fruit.migration(conn)
  let assert Ok(Nil) = example_migration_animal.migration(conn)

  let assert Ok(Nil) = sqlight.close(conn)
}
