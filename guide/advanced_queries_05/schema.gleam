//// Guide 05 — advanced queries (schema)
////
//// Extends the relationship shape with a date on the child and a query that projects
//// through `nullable(relationships...)` like the hippo case study.
//// Generate: `gleam run -- src/guide/advanced_queries_05/schema.gleam`

import gleam/option
import gleam/time/calendar.{type Date}
import swil/dsl.{
  type BacklinkWith, type BelongsTo, age, exclude_if_missing, nullable,
}

pub type Guide05Owner {
  Guide05Owner(
    email: option.Option(String),
    pets: List(Guide05Pet),
    identities: Guide05OwnerIdentities,
    relationships: Guide05OwnerRelationships,
  )
}

pub type Guide05OwnerRelationships {
  Guide05OwnerRelationships(pets: BacklinkWith(List(Guide05Pet), Nil))
}

pub type Guide05OwnerIdentities {
  ByEmail(email: String)
}

pub type Guide05Pet {
  Guide05Pet(
    name: option.Option(String),
    born_on: option.Option(Date),
    identities: Guide05PetIdentities,
    relationships: Guide05PetRelationships,
  )
}

pub type Guide05PetRelationships {
  Guide05PetRelationships(owner: option.Option(BelongsTo(Guide05Owner, Nil)))
}

pub type Guide05PetIdentities {
  ByName(name: String)
}

/// Example: derived age + owner's email for pets past a minimum age.
pub fn query_guide05_old_pets_owner_emails(
  pet: Guide05Pet,
  _magic_fields: dsl.MagicFields,
  min_age: Int,
) {
  dsl.query(pet)
  |> dsl.shape(#(
    #("age", age(exclude_if_missing(pet.born_on))),
    nullable(pet.relationships.owner).item.email,
  ))
  |> dsl.filter_bool(age(exclude_if_missing(pet.born_on)) > min_age)
  |> dsl.order_by(age(exclude_if_missing(pet.born_on)), dsl.Desc)
}
