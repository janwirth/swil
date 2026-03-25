import gleam/option

import v2/dsl.{query, filter, sort, select, age, exclude_if_missing, nullable, CalendarDate, Desc}

// ACTUAL SCHEMA
// Identies = By...

pub type Hippo {
    Hippo(name: option.Option(String),
        gender: option.Option(Bool),
         date_of_birth: option.Option(dsl.CalendarDate),
         friends: List(Hippo), //! mutual
         best_friend: MutualLink(Hippo), //! mutual
         owner: option.Option (Human), //! outlink
         identities: HippoIdentities
     )
}
// identities are required - you need at least one to be able to query
pub type HippoIdentities {
    ByNameAndDateOfBirth(name: String, date_of_birth: dsl.CalendarDate)
    // This will create exclusive index tables
    ById(id: String)
    ByCreatedAt(created_at: dsl.Timestamp) // magicFields
    ByUpdatedAt(updated_at: dsl.Timestamp) // magicFields
    ByDeletedAt(deleted_at: dsl.Timestamp) // magicFields
}

pub type Human {
    Human(
            name: option.Option (String),
            email: option.Option (String),
            hippos: List(Hippo), //! backlink.owner
    )
    HumanIdentities(
        ByNameAndEmail(name: String, email: String)
    )
}

pub type HumanIdentities {
    ByEmail(email: String)
}

pub type FriendshipProperties {
    FriendshipProperties(since: dsl.CalendarDate)
}


pub type MutualLink(a) {}
pub type MutualMultiLink(a) {}


pub fn old_friends(hippo: Hippo) {
    query(hippo)
    |> filter(fn (hippo) {age(exclude_if_missing(hippo.date_of_birth)) > 5})
    |> sort(fn(hippo) {#(age(exclude_if_missing(hippo.date_of_birth)), Desc)})
    |> select(fn(hippo) {#(age(exclude_if_missing(hippo.date_of_birth)), nullable(hippo.owner).name, nullable(hippo.owner).email)})
    // hippo would fetch all fields from hippo
    // #(hippo, hippo.owner) would fetch all fields from hippo and owner
    // #(hippo.owner) would fetch all fields from owner as {owner: {name: "John", email: "john@example.com"}}
    // #(hippo.owner.name) would fetch only the name field from owner as {owner: {name: "John"}}
    // can I isolate selects? this is overkill
    // is this enough to spec everything
}

// DERIVED
pub type Output {
    MyQueryResult(
        age: option.Option(Int),
        // we get this because there are no
        owner: OutputOwner
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