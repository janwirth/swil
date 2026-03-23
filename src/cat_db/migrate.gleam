import gleam/result

import help/migrate as migration_help
import sqlight

pub fn migrate_idempotent(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(migration_help.ensure_base_table(conn))
  use _ <- result.try(migration_help.ensure_column(
    conn,
    "name",
    "alter table cats add column name text;",
  ))
  use _ <- result.try(migration_help.ensure_column(
    conn,
    "age",
    "alter table cats add column age int;",
  ))
  sqlight.exec(
    "create unique index if not exists cats_identity_name_idx on cats (name);",
    conn,
  )
}
