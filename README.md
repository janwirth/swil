# squeal

Write types, get sqlite access
Opinionated
Soft deletes
All fields optional (idemptotent migrations)
Declarative IDs

Check out the examples

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

