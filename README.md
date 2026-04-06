# Swil

_a cute squeal_

<a href="https://www.youtube.com/shorts/tw9_khiwNZU" target="_blank">
<img src="bree.png" alt="unexpected BREEE" width="150" />
</a>

SQLite from Gleam types + small query functions → generated `*_db` (migrate, get, upsert, delete, query, api). Full case study: [`hippo_schema.gleam`](test/case_studies/hippo_schema.gleam).

**WARNING: Migrations have not been tested thoroughly yet, could lead to data loss / unexpected consequences**

## Basic usage

Create a schema module (for example under `test/case_studies/`), then regenerate the sibling `*_db` package from the repo root:

```sh
gleam run -- test/case_studies/hippo_schema.gleam
```

The first argument is the schema file path (with or without `.gleam`). Paths without a leading `src/` or `/` are resolved under `src/`, matching [`swil.gleam`](src/swil.gleam).

```gleam
// hippo_schema.gleam
import swil/dsl.{
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
  Inbetween
  Beyond
}


/// Identities define unique upsert/delete keys.
pub type HippoIdentities {
  ByNameAndDateOfBirth(name: String, date_of_birth: Date)
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

Generated code includes direct `upsert_*` / `update_*` / `delete_*` helpers on `hippo_db/api`, and **command variants** on `hippo_db/cmd` executed in batches via `execute_*_cmds` (same batching rules from `hippo_db/cmd` or the thin wrappers on `hippo_db/api`). Prefer commands when you want a list of writes, mixed variants in one call, or `Error(#(index, sqlight.Error))` pointing at the failing batch (see [`test/case_studies/hippo_cmd_test.gleam`](test/case_studies/hippo_cmd_test.gleam)).

```gleam
// my_app.gleam
import gleam/io
import gleam/option
import gleam/string
import gleam/time/calendar.{Date, January}
import hippo_db/api as hippo_api
import hippo_db/cmd as hippo_cmd
import hippo_schema
import sqlight

pub fn example(conn: sqlight.Connection) {
  let assert Ok(Nil) = hippo_api.migrate(conn)
  let dob = Date(1975, January, 1)

  // Writes via command batches (also: hippo_cmd.execute_hippo_cmds(conn, [...]))
  let assert Ok(Nil) =
    hippo_api.execute_hippo_cmds(conn, [
      hippo_cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Bree",
        date_of_birth: dob,
        gender: option.None,
      ),
      hippo_cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Bloop",
        date_of_birth: dob,
        gender: option.None,
      ),
    ])

  let assert Ok(Nil) =
    hippo_api.execute_hippo_cmds(conn, [
      hippo_cmd.UpdateHippoByNameAndDateOfBirth(
        name: "Bree",
        date_of_birth: dob,
        gender: option.Some(hippo_schema.Male),
      ),
    ])

  let assert Ok(Nil) =
    hippo_api.execute_hippo_cmds(conn, [
      hippo_cmd.DeleteHippoByNameAndDateOfBirth(name: "Bree", date_of_birth: dob),
    ])

  // Same patterns exist per entity, e.g. execute_human_cmds / HumanCommand.

  let assert Ok(recent) = hippo_api.last_100_edited_hippo(conn)
  io.println(string.inspect(recent))
  recent
}
```

You can still call the generated `upsert_*` / `update_*` / `delete_*` functions on `api` directly; commands are the structured alternative used across the test suite (e.g. [`test/case_studies/fruit_cmd_test.gleam`](test/case_studies/fruit_cmd_test.gleam), [`test/case_studies/fruit_patch_cmd_test.gleam`](test/case_studies/fruit_patch_cmd_test.gleam) for `Patch*` vs `Update*`).

## Relationships

You care about your relationships?
Let's define some

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
```

Define the inverse side with `BacklinkWith` so humans see their hippos through the same join metadata (`FriendshipAttributes` here):

```gleam
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
```

### Relationship querying

In `query_*` bodies, **traverse related entities in `dsl.shape` and `dsl.filter_bool`** the same way you read fields on the schema types. For an optional `BelongsTo`, wrap the edge in `nullable(...)` and use `.item.<field>` for the foreign row (the generator turns this into the appropriate join).

Example from [`hippo_schema.gleam`](test/case_studies/hippo_schema.gleam):

```gleam
/// Query input spec for "old hippos" with owner email in the row shape.
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

After `gleam run -- test/case_studies/hippo_schema.gleam`, call the generated API with **only** the extra parameter from the query spec (plus `conn`):

```gleam
import hippo_db/api as hippo_api
import hippo_db/cmd as hippo_cmd
import hippo_schema.{Male}
import gleam/option
import gleam/time/calendar.{Date, January}
import sqlight

pub fn relationship_query_example(conn: sqlight.Connection) {
  let assert Ok(Nil) = hippo_api.migrate(conn)
  let assert Ok(Nil) =
    hippo_api.execute_hippo_cmds(conn, [
      hippo_cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Oldie",
        date_of_birth: Date(1975, January, 1),
        gender: option.Some(Male),
      ),
    ])

  // Rows: #(Hippo, MagicFields) — shape columns are loaded via joins as needed.
  let assert Ok(old_rows) =
    hippo_api.query_old_hippos_owner_emails(conn, min_age: 30)

  let assert Ok(by_gender) =
    hippo_api.query_hippos_by_gender(conn, gender_to_match: Male)

  #(old_rows, by_gender)
}
```

Full end-to-end checks (age filter on the owner join, gender filter, name ordering) live in [`test/evolution/e2e/hippo_relationships.gleam`](test/evolution/e2e/hippo_relationships.gleam). For list edges (`Mutual`, `BacklinkWith` with `List`, and `dsl.any` in predicates), see the schema tests under [`test/schema_definition/`](test/schema_definition/).
