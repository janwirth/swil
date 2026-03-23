import gen/migration_help as shared
import sqlight
import gleam/result

pub fn migrate_v2(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(shared.ensure_base_table(conn))
  use _ <- result.try(shared.ensure_column(conn, "name", "alter table cats add column name text;"))
  shared.ensure_column(conn, "age", "alter table cats add column age int;")
}
