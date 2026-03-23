import gen/migration_help as shared
import sqlight
import gleam/result

pub fn migrate_v1(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(shared.ensure_base_table(conn))
  shared.ensure_column(conn, "name", "alter table cats add column name text;")
}
