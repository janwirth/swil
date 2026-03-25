// Drives the hand-written example migration modules (blueprints for codegen): exclusive
// fruit vs animal versions, idempotent replays, and switching back and forth.
import example_migration_animal
import example_migration_fruit
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
