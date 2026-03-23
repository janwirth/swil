import gleam/result

import gen/migration_help
import sqlight

pub fn migrate_idemptotent(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(migration_help.ensure_base_table(conn))
  migration_help.ensure_column(conn, "name", "alter table cats add column name text;")
}
