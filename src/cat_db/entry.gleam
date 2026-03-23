// Main entry for the cats schema: import this module for `Cat`, row/db types,
// `cats` / `migrate_idempotent`, and `cat` (constructor helper).

import gleam/option.{type Option}
import sqlight

import cat_db/crud
import cat_db/migrate
import cat_db/resource
import cat_db/structure

pub type Cat = resource.Cat

pub type CatForUpsert = resource.CatForUpsert

pub type CatRow = structure.CatRow

pub type CatsDb = structure.CatsDb

pub type FilterableCat = structure.FilterableCat

pub type StringRefOrValue = structure.StringRefOrValue

pub type NumRefOrValue = structure.NumRefOrValue

pub type NumCatField = structure.NumCatField

pub type StringCatField = structure.StringCatField

pub type CatField = structure.CatField

pub fn cat(name: Option(String), age: Option(Int)) -> Cat {
  resource.Cat(name:, age:)
}

pub fn cat_with_name(name: String, age: Option(Int)) -> CatForUpsert {
  resource.cat_with_name(name, age)
}

pub fn cats(conn: sqlight.Connection) -> CatsDb {
  crud.cats(conn)
}

pub fn migrate_idempotent(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migrate.migrate_idempotent(conn)
}
