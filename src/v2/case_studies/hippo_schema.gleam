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
  ByEmail(email: String)
}
// can we build an admin UI - that's the ultimate test.
// db(conn).human.delete.by_id
// OUTPUT
pub fn upsert_human_by_email(conn: sqlight.Connection, email: String, name: option.Option(String)) -> Human{
    todo ("sql etc here")
}

pub fn delete_human_by_email(conn: sqlight.Connection, email: String) -> Result(Nil, sqlight.Error) {
    todo ("sql etc here")
}
// magic field autogenned
pub fn delete_human_by_id(conn: sqlight.Connection, identity) -> Result(Nil, sqlight.Error) {
}

// how do I describe links?
// I want to figure out backlinks too
// attach metadata but still access the data

// INPUT
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
    // defining shape should mostly be optimizing to prevent fetching too much data
    shape: Some(shape),
    filter: Some(filter),
    // should we make order required?
    order: Some(order),
  )
  // can I isolate selects? this is overkill
  // is this enough to spec everything
}

// OUTPUT
pub type QueryOldHipposOwnerEmailsResult {
  QueryOldHipposOwnerEmailsResult(age: Int, owner: option.Option(Human))
}
pub type QueryOldHipposOwnerEmailsResultOwner {
  QueryOldHipposOwnerEmailsResultOwner(email: option.Option(String))
}

// INPUT
pub fn query_old_hippos_owner_emails(conn: sqlight.Connection, age: Int) {
  let sql = todo("Generate SQL from query spec")
  // includes: SELECT
    //   (strftime('%Y','now') - strftime('%Y',dob))
    //   - (strftime('%m-%d','now') < strftime('%m-%d',dob)) AS age
    // FROM hippo;
  let parameters = todo("Generate parameters from query spec - bind here the current date also?")
  // example
  let decoder = todo("Generate decoder from query spec")
  let assert Ok(result) = sqlight.query(sql, on: conn, with: parameters, expecting: decoder)
  result
}

// another example
pub fn hippos_by_gender(hippo: Hippo, gender_to_match: Bool) {
  let filter = exclude_if_missing(hippo.gender) == gender_to_match
  Query(shape: None, filter: Some(filter), order: None)
}

// OUTPUT
pub type HipposByGenderResult {
  HipposByGenderResult(magic_fields: dsl.MagicFields, name: option.Option(String), date_of_birth: option.Option(CalendarDate), owner: option.Option(#(dsl.MagicFields, Human)))
}


// then it generates a query that just writes sql amd has a decoder for the right fields

// pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
//     todo
// }
// it's just querying that needs new generators.... Maybe it's better to just generate the plain values

// use proper migrations?
// o


// next steps
// snapshot testing - input / output
// just the skeleto for the code generator
// mode: skeleton vs mode full - 
// mode: skeleton is for when we update the schema and want compiling code before the LLM writes the reference code

// DSL
// parser
// skeleton - compilable example
// reference code - what the LLM wrote - unit tested and satisfies functionality
// generate implementation - replicates reference code

// /hippo_schema.gleam
// can be generated with just the skeleton - or do we make a simple reset in case compilation fails even before?
// /hippo_db_skeleton.gleam
// migrates, upsert, delet, update (auto-genned, by id / identity), queries (based on what user wrote - building blocks for their app)
// /hippo_db_reference.gleam
