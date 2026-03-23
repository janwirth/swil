import gleeunit
import gleam/option.{Some}
import migrations/v1 as migrations_v1
import migrations/v2 as migrations_v2
import migrations/v3 as migrations_v3
import operations/v1 as operations_v1
import operations/v2 as operations_v2
import operations/v3 as operations_v3
import sqlight

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"

  assert greeting == "Hello, Joe!"
}

pub fn sqlite_v1_replay_with_queries_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = migrations_v1.migrate_v1(conn)
  let assert Ok(Nil) = migrations_v1.migrate_v1(conn)
  let assert Ok(Nil) = migrations_v1.migrate_v1(conn)

  let assert Ok(Nil) = operations_v1.insert_nubi(conn)
  let assert Ok(rows) = operations_v1.read_nubi(conn)
  let assert [#("Nubi")] = rows
}

pub fn sqlite_v2_mix_and_match_replay_with_queries_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = migrations_v2.migrate_v2(conn)
  let assert Ok(Nil) = migrations_v1.migrate_v1(conn)
  let assert Ok(Nil) = migrations_v2.migrate_v2(conn)

  let assert Ok(Nil) = operations_v2.insert_biffy(conn)
  let assert Ok(Nil) = operations_v2.update_biffy_age(conn)
  let assert Ok(rows) = operations_v2.read_biffy(conn)
  let assert [#("Biffy", 11)] = rows
}

pub fn sqlite_v3_mix_and_match_replay_with_queries_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = migrations_v3.migrate_v3(conn)
  let assert Ok(Nil) = migrations_v1.migrate_v1(conn)
  let assert Ok(Nil) = migrations_v2.migrate_v2(conn)
  let assert Ok(Nil) = migrations_v3.migrate_v3(conn)

  let assert Ok(Nil) = operations_v1.insert_nubi(conn)
  let assert Ok(Nil) = operations_v3.insert_ginny(conn)
  let assert Ok(Nil) = operations_v3.update_ginny_gender(conn)

  let assert Ok(v1_rows) = operations_v1.read_nubi(conn)
  let assert [#("Nubi")] = v1_rows

  let assert Ok(v3_rows) = operations_v3.read_ginny(conn)
  let assert [#("Ginny", 6, Some("male"))] = v3_rows
}