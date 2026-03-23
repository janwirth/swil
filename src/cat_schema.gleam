
// ## Opinionated database

// - Simple: define types once; automatic migrations follow.
// - **Codegen:** migrations are idempotent (table/column upsert).
// - **API:** one constructor per schema name, e.g. `cats(...)`.
// - **Rows:** same fields as the schema plus `created_at`, `updated_at`.
// - **CRUD:** by id; by filter; joins with typed fields (booleans, etc.).

// **Queries** — either a small builder or a typed select that transpiles to SQL:

// ```gleam
// // Predicate → SQL
// select(fn(x) { x.age > 10 })

// // Field reference → SQL fragment (example name)
// lgtr(1, x.name)
// ```
import gleam/option.{type Option}

import gen/identity
import cats_schema_generated/entry as cats

// SQLITE_LAYER_GENERATION → cats_schema_generated/{resource,structure,crud,migrate,entry}.gleam

// inspired by ash
// RESOURCE

// never directly interact with schema
pub type Cat {
  Cat(name: Option(String), age: Option(Int))
}

pub fn identities(cat: cats.FilterableCat) {
  [
    identity.Identity(cat.name)
  ] 

}



