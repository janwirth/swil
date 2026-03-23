// ## Opinionated database

// - Simple: define types once; automatic migrations follow.
// - **Codegen:** migrations are idempotent (table/column upsert).
// - **API:** one constructor per schema name, e.g. `dogs(...)`.
// - **Rows:** same fields as the schema plus `created_at`, `updated_at`.
// - **CRUD:** by id; by filter; joins with typed fields (booleans, etc.).

// **Queries** — either a small builder or a typed select that transpiles to SQL:

// ```gleam
// // Predidoge → SQL
// select(fn(x) { x.age > 10 })

// // Field reference → SQL fragment (example name)
// lgtr(1, x.name)
// ```
import gleam/option.{type Option}

import help/identity

// inspired by ash
// RESOURCE

// never directly interact with schema
pub type Dog {
  Dog(name: Option(String), age: Option(Int), is_neutered: Option(Bool))
}

pub fn identities(dog: Dog) {
  [identity.Identity2(dog.name, dog.is_neutered)]
}
