# Known issues

- imports are incorrect - need the prefix for the right version of squeal - codegen doesn't consider this
- cli is called with squeal_v2

# Squeal experiment v2

Squeal is a DB access layer for sqlite.
You describe your types & queries in a gleam subset.

```gleam
// my_schema.gleam
type Person {
  // all fields are optional to make for easy migrations
  full_name: Option.Option(Int),
  age: Option.option(Int),
  identities: PersonIdentities
}

type PersonIdentities {
  ByFullName
}

type Pet {
  owner: Option.option(Person),
  identities: PetIdentities
}

type PersonIdentities {
  ByFullName
}

```

Then you run a generator

```
squeal src/my_schema.gleam
```

You get a nicely typed DB access layer

```gleam
migration
// Migrations are idempotent and n
```

## Approach

- validate
- migrate
- mutate
- query

- syntax module
  - reads spec
  - validates
  - creates todo block

- Build case studies
- cover each module independently, breadth
- first
- avoid cake
- it's better when code is written by hand, as in, viewed as 'competing' module
- gleamgan can stay but will become a thin layer arounnd sql that gets executed

## Focus

Reference: geldata (ex edgedb) code generation for typescript

- call functions, get back typed data.

- Dev-Friendly for now (me and user bc less complexity - just works)
  - no mgirations

## Out of scope

- decentralized
  - soft delete
  - syncing / WAL merge whatever

# squeal

Write types, get sqlite access
Opinionated
Soft deletes
All fields optional (idemptotent migrations)

Declarative identities
Unique index / identities can not be dropped

Check out the examples

## Usage

```cat_schema.gleam

type Cat {
    age:...

}
// copy this example from tests?


```

Auto-generates during gleam dev cat_db. which you can use

```

import cat_db.gleam
```

## CLI

Generate a SQLite access layer from a schema module:

```bash
gleam run -m squeal -- cat_schema
```

This reads `src/cat_schema.gleam` and writes generated files to the layer
derived from the first schema type name as `<type>_db` (for example `src/cat_db/`).

Common commands:

```bash
# Generate cat DB layer
gleam run -m squeal -- cat_schema

# Generate dog DB layer
gleam run -m squeal -- dog_schema

# Regenerate cat + dog ORM layers in one step
gleam run -m regenerate_orm_layers
```

## Testing with generated ORM code

For ORM integration tests (`cat_orm_test` / `dog_orm_test`), regenerate before
test compile:

```bash
bun run test
```

Equivalent manual flow:

```bash
gleam run -m regenerate_orm_layers && gleam test
```
