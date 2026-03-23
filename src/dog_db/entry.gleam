// Main entry for the dogs schema: import this module for `Dog`, row/db types,
// `dogs` / `migrate_idempotent`, and `dog` (constructor helper).

import gleam/option.{type Option}
import sqlight

import dog_db/crud
import dog_db/migrate
import dog_db/resource
import dog_db/structure

pub type Dog = resource.Dog

pub type DogForUpsert = resource.DogForUpsert

pub type DogRow = structure.DogRow

pub type DogsDb = structure.DogsDb

pub type FilterableDog = structure.FilterableDog

pub type StringRefOrValue = structure.StringRefOrValue

pub type NumRefOrValue = structure.NumRefOrValue

pub type NumDogField = structure.NumDogField

pub type StringDogField = structure.StringDogField

pub type DogField = structure.DogField

pub fn dog(name: Option(String), age: Option(Int), is_neutered: Option(Bool)) -> Dog {
  resource.Dog(name:, age:, is_neutered:)
}

pub fn dog_with_name_is_neutered(name: String, is_neutered: Bool, age: Option(Int)) -> DogForUpsert {
  resource.dog_with_name_is_neutered(name, age, is_neutered)
}

pub fn dogs(conn: sqlight.Connection) -> DogsDb {
  crud.dogs(conn)
}

pub fn migrate_idempotent(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migrate.migrate_idempotent(conn)
}
