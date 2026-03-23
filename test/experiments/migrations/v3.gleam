import gleam/result

import help/migrate as migration_help
import sqlight

pub fn migrate_idempotent(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(migration_help.ensure_base_table(conn, "cats"))
  use _ <- result.try(migration_help.ensure_column(
    conn,
    "cats",
    "name",
    "alter table cats add column name text;",
  ))
  use _ <- result.try(migration_help.ensure_column(
    conn,
    "cats",
    "age",
    "alter table cats add column age int;",
  ))
  migration_help.ensure_column(
    conn,
    "cats",
    "gender",
    "alter table cats add column gender text;",
  )
}
