// This module ensures that idempotent migrations are in deed possible
// and provides some example
// all squeal generated migrations should behave like this
// the generated ones for now are not tested across version fuzzing, just idempotency
// that means, v1,v3,v2 etc. all should ensure their respective version queries are possible after migration is run, regardless of order and frequency of migration runs
import experiments/migrations/operations/v1 as operations_v1
import experiments/migrations/operations/v2 as operations_v2
import experiments/migrations/operations/v3 as operations_v3
import experiments/migrations/v1 as migrations_v1
import experiments/migrations/v2 as migrations_v2
import experiments/migrations/v3 as migrations_v3
import gleam/option.{Some}
import sqlight

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"

  assert greeting == "Hello, Joe!"
}

pub fn sqlite_v1_replay_with_queries_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = migrations_v1.migrate_idempotent(conn)
  let assert Ok(Nil) = migrations_v1.migrate_idempotent(conn)
  let assert Ok(Nil) = migrations_v1.migrate_idempotent(conn)

  let assert Ok(Nil) = operations_v1.insert_nubi(conn)
  let assert Ok(rows) = operations_v1.read_nubi(conn)
  let assert [#("Nubi")] = rows
}

pub fn sqlite_v2_mix_and_match_replay_with_queries_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = migrations_v2.migrate_idempotent(conn)
  let assert Ok(Nil) = migrations_v1.migrate_idempotent(conn)
  let assert Ok(Nil) = migrations_v2.migrate_idempotent(conn)

  let assert Ok(Nil) = operations_v2.insert_biffy(conn)
  let assert Ok(Nil) = operations_v2.update_biffy_age(conn)
  let assert Ok(rows) = operations_v2.read_biffy(conn)
  let assert [#("Biffy", 11)] = rows
}

pub fn sqlite_v3_mix_and_match_replay_with_queries_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = migrations_v3.migrate_idempotent(conn)
  let assert Ok(Nil) = migrations_v1.migrate_idempotent(conn)
  let assert Ok(Nil) = migrations_v2.migrate_idempotent(conn)
  let assert Ok(Nil) = migrations_v3.migrate_idempotent(conn)

  let assert Ok(Nil) = operations_v1.insert_nubi(conn)
  let assert Ok(Nil) = operations_v3.insert_ginny(conn)
  let assert Ok(Nil) = operations_v3.update_ginny_gender(conn)

  let assert Ok(v1_rows) = operations_v1.read_nubi(conn)
  let assert [#("Nubi")] = v1_rows

  let assert Ok(v3_rows) = operations_v3.read_ginny(conn)
  let assert [#("Ginny", 6, Some("male"))] = v3_rows
}
