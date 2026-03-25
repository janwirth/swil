import gleam/option
import dsl.{
  type Backlink, type BelongsTo, type CalendarDate, type Mutual, Desc, Query,
  age, exclude_if_missing, nullable,
}

/// Example schema module.
///
/// This module intentionally contains only declarative schema/query input code.
/// Generated SQL-facing output belongs in `hippo_db`.
pub type Hippo {
  Hippo(
    name: option.Option(String),
    gender: option.Option(Bool),
    date_of_birth: option.Option(CalendarDate),
    identities: HippoIdentities,
    relationships: HippoRelationships,
  )
}

pub type HippoRelationships {
  HippoRelationships(
    friends: option.Option(Mutual(List(Hippo))),
    best_friend: option.Option(Mutual(Hippo)),
    owner: option.Option(BelongsTo(Human)),
  )
}

/// Identities define unique upsert/delete keys.
pub type HippoIdentities {
  ByNameAndDateOfBirth(name: String, date_of_birth: CalendarDate)
  ById(id: String)
}

pub type Human {
  Human(
    name: option.Option(String),
    email: option.Option(String),
    hippos: List(Hippo),
    identities: HumanIdentities,
    relationships: HumanRelationships,
  )
}

pub type HumanRelationships {
  HumanRelationships(hippos: Backlink(List(Hippo)))
}

pub type HumanIdentities {
  ByEmail(email: String)
}

/// Query input spec for "old hippos owner emails".
pub fn old_hippos_owner_emails(hippo: Hippo, min_age: Int) {
  let shape = #(
    #("age", age(exclude_if_missing(hippo.date_of_birth))),
    nullable(hippo.relationships.owner).item.email,
  )
  let filter = age(exclude_if_missing(hippo.date_of_birth)) > min_age
  let order = #(Desc, age(exclude_if_missing(hippo.date_of_birth)))

  Query(
    shape: option.Some(shape),
    filter: option.Some(filter),
    order: option.Some(order),
  )
}

/// Query input spec for "hippos by gender".
pub fn hippos_by_gender(hippo: Hippo, gender_to_match: Bool) {
  let filter = exclude_if_missing(hippo.gender) == gender_to_match
  Query(shape: option.None, filter: option.Some(filter), order: option.None)
}
