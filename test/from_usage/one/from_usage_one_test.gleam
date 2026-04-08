import sqlight
import from_usage/one/tuna_db/migration
import from_usage/one/tuna_db/query
import gleam/io

pub fn mig_and_use_test() {
  let assert Ok(conn) = sqlight.open("test/from_usage/one/tuna.db")
  let assert Ok(Nil) = migration.migration(conn)
  let assert Ok(_) = query.last_100_edited_importedtrack(conn)
  sqlight.close(conn)
}