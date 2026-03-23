# db_platform

[![Package Version](https://img.shields.io/hexpm/v/db_platform)](https://hex.pm/packages/db_platform)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/db_platform/)

```sh
gleam add db_platform@1
```

```gleam
import db_platform

pub fn main() -> Nil {
  // TODO: An example of the project in use
}
```

Further documentation can be found at <https://hexdocs.pm/db_platform>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

## Opinionated database

- Simple: define types once; automatic migrations follow.
- **Codegen:** migrations are idempotent (table/column upsert).
- **API:** one constructor per schema name, e.g. `cats(...)`.
- **Rows:** same fields as the schema plus `created_at`, `updated_at`.
- **CRUD:** by id; by filter; joins with typed fields (booleans, etc.).

**Queries** — either a small builder or a typed select that transpiles to SQL:

```gleam
// Predicate → SQL
select(fn(x) { x.age > 10 })

// Field reference → SQL fragment (example name)
lgtr(1, x.name)
```
