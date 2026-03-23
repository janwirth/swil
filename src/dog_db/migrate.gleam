import gleam/result

import help/migrate as migration_help
import sqlight

pub fn migrate_idempotent(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(migration_help.ensure_base_table(conn))
  use _ <- result.try(migration_help.ensure_column(conn, "name", "alter table dogs add column name text;"))
  use _ <- result.try(migration_help.ensure_column(conn, "age", "alter table dogs add column age int;"))
  use _ <- result.try(migration_help.ensure_column(conn, "is_neutered", "alter table dogs add column is_neutered int;"))
  sqlight.exec(
    "create unique index if not exists dogs_identity_idx on dogs (name, is_neutered);",
    conn,
  )
}
