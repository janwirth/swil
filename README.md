# Swil

_a cute squeal_

<a href="https://www.youtube.com/shorts/tw9_khiwNZU" target="_blank">
<img src="bree.png" alt="unexpected BREEE" width="150" />
</a>


SQLite from Gleam types + small query functions → generated `*_db` (migrate, get, upsert, delete, query, api). Full case study: [`hippo_schema.gleam`](src/case_studies/hippo_schema.gleam).

**WARNING: Migrations have not been tested thoroughly yet, could lead to data loss / unexpected consequences**

## Basic usage

First create the following file, then run `swil hippo_schema`.

```gleam
// hippo_schema.gleam
import swil/dsl/dsl.{
  type BacklinkWith, type BelongsTo, type Mutual, age, exclude_if_missing,
  nullable,
}
import gleam/option
import gleam/time/calendar.{type Date}

pub type Hippo {
  Hippo(
    // all fields are optional which makes migrations trivial
    name: option.Option(String),
    gender: option.Option(GenderScalar),
    date_of_birth: option.Option(Date),

    // this is required - this is how we defined how create / update entries
    identities: HippoIdentities,

    // optional, we get to this later
    relationships: HippoRelationships,
  )
}

// automatically encoded union types
pub type GenderScalar {
  Male
  Female
}


/// Identities define unique upsert/delete keys.
pub type HippoIdentities {
  ByNameAndDateOfBirth(name: String, date_of_birth: Date)
}
```

This gives you the following nicely typed api:

```gleam
// my_app.gleam
import gleam/io
import gleam/option
import gleam/string
import gleam/time/calendar.{Date, January}
import hippo_db/api as hippo_api
import hippo_schema
import sqlight

pub fn example(conn: sqlight.Connection) {
  let assert Ok(Nil) = hippo_api.migrate(conn)
  let dob = Date(1975, January, 1)
  // let's create some hippos
  let assert Ok(#(_hippo, _)) =
    hippo_api.upsert_hippo_by_name_and_date_of_birth(
      conn,
      name: "Bree",
      date_of_birth: dob,
      gender: option.None,
    )
  // yes all born on the same day
  let assert Ok(#(_hippo, _)) =
    hippo_api.upsert_hippo_by_name_and_date_of_birth(
      conn,
      name: "Bloop",
      date_of_birth: dob,
      gender: option.None,
    )

  // update
  let assert Ok(#(_, _)) =
    hippo_api.update_hippo_by_name_and_date_of_birth(
      conn,
      name: "Bree",
      date_of_birth: dob,
      gender: option.Some(hippo_schema.Male),
    )
  // delete
  let assert Ok(Nil) =
    hippo_api.delete_hippo_by_name_and_date_of_birth(
      conn,
      name: "Bree",
      date_of_birth: dob,
    )

  // list all - convenient inspect helper
  let assert Ok(recent) = hippo_api.last_100_edited_hippo(conn)
  io.println(string.inspect(recent))
  recent
}
```

## Relationships

You care about your relationships?

```gleam
// continuing hippo_schema.gleam
pub type HippoRelationships {
  HippoRelationships(
    // we reference other types
    // the friendship attributes define cols on the join table

    // we support mutual lists (many to many)
    friends: option.Option(Mutual(List(Hippo), FriendshipAttributes)),

    // and one-to-one (I should test this explicitly)
    best_friend: option.Option(Mutual(Hippo, FriendshipAttributes)),

    // the owner is one to one
    owner: option.Option(BelongsTo(Human, Nil)),
  )
}

pub type FriendshipAttributes {
  // yeeeah we are old friends :))
  FriendshipAttributes(since: option.Option(Date))
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
  HumanRelationships(hippos: BacklinkWith(List(Hippo), FriendshipAttributes))
}

pub type HumanIdentities {
  ByEmail(email: String)
}

/// Query input spec for "old hippos owner emails".
pub fn query_old_hippos_owner_emails(
  hippo: Hippo,
  _magic_fields: dsl.MagicFields,
  min_age: Int,
) {
  dsl.query(hippo)
  |> dsl.shape(#(
    #("age", age(exclude_if_missing(hippo.date_of_birth))),
    nullable(hippo.relationships.owner).item.email,
  ))
  |> dsl.filter_bool(age(exclude_if_missing(hippo.date_of_birth)) > min_age)
  |> dsl.order(age(exclude_if_missing(hippo.date_of_birth)), dsl.Desc)
}

/// Query input spec for "old hippos owner emails".
pub fn query_old_hippos_owner_names(
  hippo: Hippo,
  _magic_fields: dsl.MagicFields,
  min_age: Int,
) {
  dsl.query(hippo)
  |> dsl.shape(#(
    #("age", age(exclude_if_missing(hippo.date_of_birth))),
    nullable(hippo.relationships.owner).item.email,
  ))
  |> dsl.filter_bool(age(exclude_if_missing(hippo.date_of_birth)) > min_age)
  |> dsl.order(age(exclude_if_missing(hippo.date_of_birth)), dsl.Desc)
}

/// Query input spec for "hippos by gender".
pub fn query_hippos_by_gender(
  hippo: Hippo,
  _magic_fields: dsl.MagicFields,
  gender_to_match: GenderScalar,
) {
  dsl.query(hippo)
  |> dsl.shape(hippo)
  |> dsl.filter_bool(exclude_if_missing(hippo.gender) == gender_to_match)
  |> dsl.order(hippo.name, dsl.Desc)
}
```
