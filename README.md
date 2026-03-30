# Skwil

<img src="bree.png" alt="unexpected BREEE" width="150" />

SQLite from Gleam types + small query functions → generated `*_db` (migrate, get, upsert, delete, query, api). Full case study: [`hippo_schema.gleam`](src/case_studies/hippo_schema.gleam).

```gleam
import case_studies/hippo_db/api as hippo_api
import case_studies/hippo_schema.{Male}
import gleam/option.{Some}
import gleam/time/calendar.{Date, January}
import sqlight

let assert Ok(conn) = sqlight.open(":memory:")
let assert Ok(Nil) = hippo_api.migrate(conn)
let assert Ok(_) =
  hippo_api.upsert_hippo_by_name_and_date_of_birth(
    conn,
    name: "Oldie",
    date_of_birth: Date(1975, January, 1),
    gender: Some(Male),
  )
let assert Ok(rows) = hippo_api.query_old_hippos_owner_emails(conn, min_age: 30)
```

```bash
gleam run -m skwil -- case_studies/hippo_schema
```

Incremental schema:

```gleam
import gleam/option
import gleam/time/calendar.{type Date}

pub type GenderScalar {
  Male
  Female
}

pub type Hippo {
  Hippo(
    name: option.Option(String),
    gender: option.Option(GenderScalar),
    date_of_birth: option.Option(Date),
    identities: HippoIdentities, // next snippet
    relationships: HippoRelationships, // after identities
  )
}
```

`Option` fields → nullable SQL columns, additive migrations.

```gleam
// Natural keys: unique index + get / upsert / delete by these args (not only row id).
pub type HippoIdentities {
  ByNameAndDateOfBirth(name: String, date_of_birth: Date)
}
```

```gleam
import skwil/dsl/dsl.{type BacklinkWith, type BelongsTo, type Mutual}

pub type HippoRelationships {
  HippoRelationships(
    friends: option.Option(Mutual(List(Hippo), FriendshipAttributes)),
    best_friend: option.Option(Mutual(Hippo, FriendshipAttributes)),
    owner: option.Option(BelongsTo(Human, Nil)),
  )
}

pub type FriendshipAttributes {
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

// Inverse of `Hippo.owner` — same link, other direction.
pub type HumanRelationships {
  HumanRelationships(hippos: BacklinkWith(List(Hippo), FriendshipAttributes))
}

pub type HumanIdentities {
  ByEmail(email: String)
}
```

`Mutual` / `BelongsTo` / `BacklinkWith` = how edges are stored and traversed.

```gleam
import skwil/dsl/dsl

pub fn query_hippos_by_gender(
  hippo: Hippo,
  _magic_fields: dsl.MagicFields,
  gender_to_match: GenderScalar,
) {
  dsl.query(hippo)
  |> dsl.shape(hippo)
  |> dsl.filter_bool(dsl.exclude_if_missing(hippo.gender) == gender_to_match)
  |> dsl.order(hippo.name, dsl.Desc)
}
```

```gleam
import skwil/dsl/dsl.{age, exclude_if_missing, nullable}

// Same derived `age(...)` in shape, filter, and order so SQL lines up.
// `nullable(owner)` — owner may be missing; still project email when present.
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
```

More e2e: [`test/evolution/e2e/hippo_relationships.gleam`](test/evolution/e2e/hippo_relationships.gleam). Tests: `gleam test`.

[Squirrel](https://hexdocs.pm/squirrel/index.html) — different SQL-in-Gleam style; mix if you want.

**Inspirations:** [Ash](https://ash-hq.org/), [Gel](https://geldata.com/) (formerly EdgeDB / geldata).
