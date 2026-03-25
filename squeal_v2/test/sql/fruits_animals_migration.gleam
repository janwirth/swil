// Drives the hand-written example migration modules (blueprints for codegen): exclusive
// fruit vs animal versions, idempotent replays, and switching back and forth.
import example_migration_animal
import example_migration_fruit
import generators/migration
import schema_definition
import simplifile
import sqlight
const schema1 = "
import gleam/option

pub type Fruit {
    Fruit(
        name: option.Option(String),
        color: option.Option(String),
        price: option.Option(Float),
        quantity: option.Option(Int),
        identities: FruitIdentities,
    )
}
pub type FruitIdentities {
    ByName(name: String)
}
"

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

pub fn pragma_migration_codegen_matches_example_blueprints_test() {
  let assert Ok(fruit_expected) =
    simplifile.read("src/example_migration_fruit.gleam")
  let assert Ok(animal_expected) =
    simplifile.read("src/example_migration_animal.gleam")

  let assert Ok(fruit_def) = schema_definition.parse_module(schema1)
  let assert Ok(animal_def) = schema_definition.parse_module(schema2)

  let fruit_gleam =
    migration.generate_pragma_migration_module(fruit_def, "example_migration_fruit")
  let animal_gleam =
    migration.generate_pragma_migration_module(animal_def, "example_migration_animal")

  assert fruit_gleam == fruit_expected
  assert animal_gleam == animal_expected
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
