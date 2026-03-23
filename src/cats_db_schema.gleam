
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
import gleam/option.{type Option, None, Some}
import sqlight

import cats_schema_generated/crud as cats_crud
import cats_schema_generated/entry as cats
import cats_schema_generated/structure as gen
import gen/filter
import gen/identity

// SQLITE_LAYER_GENERATION → cats_schema_generated/{resource,structure,crud,migrate,entry}.gleam

// inspired by ash
// RESOURCE

// never directly interact with schema
type Cat {
  Cat(name: Option(String), age: Option(Int))
}

fn identities(cat: Cat) {
  [
    identity.Identity(gen.NameField)
  ]

}




// only supports optional fields
// runtime code can handle defaults

// hand-written queries with generated query builder
pub fn cat_older_than(age: Int) -> cats_crud.Filter {
    fn (cat: cats.FilterableCat) {
        filter.Gt(left: cat.age, right: gen.NumValue(value: age))
    }
}

pub fn cat_age_eq(age: Int) -> cats_crud.Filter {
    fn(cat: cats.FilterableCat) {
        filter.Eq(left: cat.age, right: gen.NumValue(value: age))
    }
}


pub fn cat_name_excludes(substr: String) -> cats_crud.Filter {
    fn(cat: cats.FilterableCat) {
        filter.NotContains(left: cat.name, right: gen.StringValue(value: substr))
    }
}
// make this type genriic and more comfortable to type

pub fn cat_older_than_and_name_excludes(
    age: Int,
    substr: String,
) -> Filter {
    fn(cat: cats.FilterableCat) {
        filter.And(
            left: filter.Gt(left: cat.age, right: gen.NumValue(value: age)),
            right: filter.NotContains(left: cat.name, right: gen.StringValue(value: substr)),
        )
    }
}

pub type Filter = cats_crud.Filter

pub fn main() -> Nil {
  use conn <- sqlight.with_connection(":memory:")
  let arg = cats_crud.filter_arg(Some(cat_older_than(6)), None)
  let _ = cats.cats(conn).migrate()
  let cats = cats.cats(conn).read_many(arg)

  Nil
}
