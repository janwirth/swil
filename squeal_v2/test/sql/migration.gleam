// given two very basic schemas, generate the migration sql
// the migrations should be idempotent - fuzz order with 3 different variants
// write in style of squeal schema
import schema_definition
import generators/migration
// they should include
// unique index
// magic fields

const schema1 = "
import gleam/option

pub type Fruit {
    Fruit(
        name: option.Option(String),
        color: option.Option(String),
        price: option.Option(Float),
        quantity: option.Option(Int),
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
        name: String,
        species: String,
        age: Int,
        color: String,
    )
}
"



pub fn idempotent_migration_test() {
    let assert Ok(parsed1) = schema_definition.parse_module(schema1)
    let assert Ok(parsed2) = schema_definition.parse_module(schema2)

    let assert Ok(migration1) = migration.generate_migration(parsed1, parsed2)
    let assert Ok(migration2) = migration.generate_migration(parsed2, parsed1)
    let assert Ok(migration3) = migration.generate_migration(parsed1, parsed2)

    assert migration1 == migration2
    assert migration1 == migration3
    assert migration2 == migration3
}