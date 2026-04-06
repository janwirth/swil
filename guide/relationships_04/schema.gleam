//// Guide 04 — relationships (schema)
////
//// Parent lists children; child holds `BelongsTo(parent, edge_attrs)`.
//// Generate: `gleam run -- src/guide/relationships_04/schema.gleam`
////
//// Insert order: create owners first, then pets (FK to owner).

import gleam/option
import swil/dsl.{type BacklinkWith, type BelongsTo}

pub type Guide04Owner {
  Guide04Owner(
    email: option.Option(String),
    pets: List(Guide04Pet),
    identities: Guide04OwnerIdentities,
    relationships: Guide04OwnerRelationships,
  )
}

pub type Guide04OwnerRelationships {
  Guide04OwnerRelationships(pets: BacklinkWith(List(Guide04Pet), Nil))
}

pub type Guide04OwnerIdentities {
  ByEmail(email: String)
}

pub type Guide04Pet {
  Guide04Pet(
    name: option.Option(String),
    identities: Guide04PetIdentities,
    relationships: Guide04PetRelationships,
  )
}

pub type Guide04PetRelationships {
  Guide04PetRelationships(owner: option.Option(BelongsTo(Guide04Owner, Nil)))
}

pub type Guide04PetIdentities {
  ByName(name: String)
}
