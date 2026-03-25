import gleam/option.{type Option, Some, None}
import sqlight

import gleam/time/timestamp.{type Timestamp}
import v2/dsl.{type Backlink, type BelongsTo, type CalendarDate, type Mutual, Desc, age, exclude_if_missing, nullable, Query}

// ACTUAL SCHEMA
// Identies = By...

// This is how you define types by constructors
// additional magic fields are : created_at, updated_at, deleted_at, id
// you can't redefined them
// every data field is optional to make migrations easier
// anything you define here you can then use in your queries
pub type Hippo {
  Hippo(
    name: option.Option(String),
    gender: option.Option(Bool),
    date_of_birth: option.Option(CalendarDate),
    // this is inspired by ash - you define identities for each type, those create indexes

    identities: HippoIdentities,
    // same for relationships - you define them and most of them automatically create backlinks
    relationships: HippoRelationships,
  )
}

pub type HippoRelationships {
  HippoRelationships(
    // mutual lists point to the same field in both items
    // and they resolve back and forth automatically
    friends: option.Option(Mutual(List(Hippo))),
    // they support single and multi
    best_friend: option.Option(Mutual(Hippo)),
    // outlinks point to a different field in an item of another type
    owner: option.Option(BelongsTo(Human)),
  )
}

// identities define by what key to insert items into the database
// this is important to ensure idempotency on upsert
pub type HippoIdentities {
  ByNameAndDateOfBirth(name: String, date_of_birth: CalendarDate)
  // This will create exclusive index tables
  ById(id: String)
}

pub type Human {
  Human(
    name: option.Option(String),
    email: option.Option(String),
    hippos: List(Hippo),
    // backlink.owner is automatically resolved -- because there is only one backlink to hippo that is possible
    identities: HumanIdentities,
    relationships: HumanRelationships,
  )
}

pub type HumanRelationships {
  HumanRelationships(
    // backlinks resolved always list time
    hippos: Backlink(List(Hippo)),
  )
}

pub type HumanIdentities {
  ByNameAndEmail(name: String, email: String)
  ByEmail(email: String)
}

// how do I describe links?
// I want to figure out backlinks too
// attach metadata but still access the data


pub fn old_hippos_owner_emails(hippo: Hippo, min_age: Int) {
  // departure from edgedb - nullable only automatic if it's a leaf - if it's a node we must be explicit
  // hippo or None would fetch all fields from hippo
  // #(hippo, hippo.owner) would fetch all fields from hippo and owner
  // #(hippo.owner) would fetch all fields from owner as {owner: {name: "John", email: "john@example.com"}}
  // #(hippo.owner.name) would fetch only the name field from owner as {owner: {name: "John"}}

  let shape = #(
    #("age", age(exclude_if_missing(hippo.date_of_birth))),
    nullable(hippo.relationships.owner).item.email,
  )
  let filter = age(exclude_if_missing(hippo.date_of_birth)) > min_age
  let order = #(Desc, age(exclude_if_missing(hippo.date_of_birth)))

  Query(
    shape: Some(shape),
    filter: Some(filter),
    order: Some(order),
  )
  // can I isolate selects? this is overkill
  // is this enough to spec everything
}

// generates
pub type QueryOldFriendsResult {
  QueryOldFriends(age: Int, owner: option.Option(Human))
}

pub fn query_old_hippos_owner_emails(conn: sqlight.Connection, age: Int) {
  let sql = todo("Generate SQL from query spec")
  let parameters = todo("Generate parameters from query spec")
  let decoder = todo("Generate decoder from query spec")
  let assert Ok(result) = sqlight.query(sql, on: conn, with: parameters, expecting: decoder)
  result
}

// another example
pub fn hippos_by_gender(hippo: Hippo, gender_to_match: Bool) {
  let filter = exclude_if_missing(hippo.gender) == gender_to_match
  Query(shape: None, filter: Some(filter), order: None)

}

// DERIVED
pub type Output {
  MyQueryResult(
    age: option.Option(Int),
    // we get this because there are no
    owner: OutputOwner,
  )
}

pub type OutputOwner {
  OutputOwner(name: option.Option(String), email: option.Option(String))
}
// then it generates a query that just writes sql amd has a decoder for the right fields

// pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
//     todo
// }
// it's just querying that needs new generators.... Maybe it's better to just generate the plain values

// use proper migrations?
// o
