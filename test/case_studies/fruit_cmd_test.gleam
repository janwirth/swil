/// Tests for FruitCommand and execute_fruit_cmds.
///
/// Covers: pure construction, round-trip, batch equivalence, interleaved
/// variant ordering, and error-index reporting.
import case_studies/fruit_db/api
import case_studies/fruit_db/cmd
import gleam/list
import gleam/option.{None, Some}
import sqlight

// ── Helpers ───────────────────────────────────────────────────────────────────

fn open_db() -> sqlight.Connection {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)
  conn
}

fn seed_apple(conn: sqlight.Connection) -> Int {
  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "apple",
        color: Some("red"),
        price: Some(1.0),
        quantity: Some(10),
      ),
    ])
  let assert Ok(Some(#(_, magic))) = api.get_fruit_by_name(conn, name: "apple")
  magic.id
}

// ── Pure construction ─────────────────────────────────────────────────────────

/// Commands are plain values; they can be built and compared without a DB.
pub fn pure_construction_test() {
  let a =
    cmd.UpsertFruitByName(
      name: "mango",
      color: Some("yellow"),
      price: Some(3.5),
      quantity: None,
    )
  let b =
    cmd.UpsertFruitByName(
      name: "mango",
      color: Some("yellow"),
      price: Some(3.5),
      quantity: None,
    )
  let assert True = a == b

  let d = cmd.DeleteFruitByName(name: "mango")
  let assert True = d == cmd.DeleteFruitByName(name: "mango")

  let u =
    cmd.UpdateFruitById(
      id: 42,
      name: Some("mango"),
      color: None,
      price: None,
      quantity: Some(5),
    )
  let assert True = u == cmd.UpdateFruitById(id: 42, name: Some("mango"), color: None, price: None, quantity: Some(5))

  let cmds = [a, d, u]
  let assert 3 = list.length(cmds)
}

// ── Round-trip ────────────────────────────────────────────────────────────────

/// execute_fruit_cmds then read back should reflect the applied changes.
pub fn round_trip_upsert_test() {
  let conn = open_db()

  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "kiwi",
        color: Some("green"),
        price: Some(2.0),
        quantity: Some(5),
      ),
    ])

  let assert Ok(Some(#(fruit, _))) = api.get_fruit_by_name(conn, name: "kiwi")
  let assert Some("kiwi") = fruit.name
  let assert Some("green") = fruit.color
  let assert Some(2.0) = fruit.price
  let assert Some(5) = fruit.quantity

  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_delete_test() {
  let conn = open_db()
  let _ = seed_apple(conn)

  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [cmd.DeleteFruitByName(name: "apple")])

  let assert Ok(None) = api.get_fruit_by_name(conn, name: "apple")

  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_update_by_id_test() {
  let conn = open_db()
  let id = seed_apple(conn)

  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpdateFruitById(
        id: id,
        name: Some("apple"),
        color: Some("green"),
        price: Some(0.5),
        quantity: Some(99),
      ),
    ])

  let assert Ok(Some(#(fruit, _))) = api.get_fruit_by_id(conn, id: id)
  let assert Some("green") = fruit.color
  let assert Some(0.5) = fruit.price
  let assert Some(99) = fruit.quantity

  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_update_by_name_test() {
  let conn = open_db()
  let _ = seed_apple(conn)

  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpdateFruitByName(
        name: "apple",
        color: Some("golden"),
        price: Some(1.5),
        quantity: Some(20),
      ),
    ])

  let assert Ok(Some(#(fruit, _))) = api.get_fruit_by_name(conn, name: "apple")
  let assert Some("golden") = fruit.color
  let assert Some(1.5) = fruit.price

  let assert Ok(Nil) = sqlight.close(conn)
}

// ── Batch equivalence ─────────────────────────────────────────────────────────

/// Three same-variant ops in one call must produce the same DB state as three
/// separate single-op calls.
pub fn batch_same_as_sequential_test() {
  let conn_batch = open_db()
  let conn_seq = open_db()

  let cmds = [
    cmd.UpsertFruitByName(
      name: "fig",
      color: Some("purple"),
      price: Some(4.0),
      quantity: Some(1),
    ),
    cmd.UpsertFruitByName(
      name: "guava",
      color: Some("pink"),
      price: Some(5.0),
      quantity: Some(2),
    ),
    cmd.UpsertFruitByName(
      name: "honeydew",
      color: Some("green"),
      price: Some(6.0),
      quantity: Some(3),
    ),
  ]

  // Batched call
  let assert Ok(Nil) = cmd.execute_fruit_cmds(conn_batch, cmds)

  // Sequential single-op calls
  list.each(cmds, fn(c) {
    let assert Ok(Nil) = cmd.execute_fruit_cmds(conn_seq, [c])
  })

  // Both DBs should have identical rows for each name.
  list.each(["fig", "guava", "honeydew"], fn(name) {
    let assert Ok(Some(#(fb, _))) = api.get_fruit_by_name(conn_batch, name: name)
    let assert Ok(Some(#(fs, _))) = api.get_fruit_by_name(conn_seq, name: name)
    let assert True = fb.name == fs.name
    let assert True = fb.color == fs.color
    let assert True = fb.price == fs.price
    let assert True = fb.quantity == fs.quantity
  })

  let assert Ok(Nil) = sqlight.close(conn_batch)
  let assert Ok(Nil) = sqlight.close(conn_seq)
}

// ── Interleaved variants ──────────────────────────────────────────────────────

/// A mixed [A, B, A] sequence must apply all commands and preserve order.
pub fn interleaved_variants_test() {
  let conn = open_db()

  // Seed "plum" so we can update it.
  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "plum",
        color: Some("purple"),
        price: Some(3.0),
        quantity: Some(7),
      ),
    ])

  let id = {
    let assert Ok(Some(#(_, magic))) =
      api.get_fruit_by_name(conn, name: "plum")
    magic.id
  }

  // [UpsertByName, UpdateById, UpsertByName] — two different variant types.
  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "lychee",
        color: Some("pink"),
        price: Some(8.0),
        quantity: Some(4),
      ),
      cmd.UpdateFruitById(
        id: id,
        name: Some("plum"),
        color: Some("dark-purple"),
        price: Some(3.5),
        quantity: Some(7),
      ),
      cmd.UpsertFruitByName(
        name: "lime",
        color: Some("green"),
        price: Some(1.0),
        quantity: Some(12),
      ),
    ])

  // All three effects should be visible.
  let assert Ok(Some(#(lychee, _))) =
    api.get_fruit_by_name(conn, name: "lychee")
  let assert Some("pink") = lychee.color

  let assert Ok(Some(#(plum, _))) = api.get_fruit_by_id(conn, id: id)
  let assert Some("dark-purple") = plum.color

  let assert Ok(Some(#(lime, _))) = api.get_fruit_by_name(conn, name: "lime")
  let assert Some("green") = lime.color

  let assert Ok(Nil) = sqlight.close(conn)
}

// ── Error index ───────────────────────────────────────────────────────────────

/// A failing command at index 0 returns Error(#(0, _)).
/// Trigger the error via a UNIQUE constraint violation: renaming a fruit to a
/// name that is already taken causes the unique index on "name" to reject it.
pub fn error_index_zero_test() {
  let conn = open_db()

  // Seed two fruits so there is a name collision to trigger.
  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "apple-ei",
        color: Some("red"),
        price: Some(1.0),
        quantity: Some(1),
      ),
      cmd.UpsertFruitByName(
        name: "banana-ei",
        color: Some("yellow"),
        price: Some(2.0),
        quantity: Some(2),
      ),
    ])

  let apple_id = {
    let assert Ok(Some(#(_, magic))) =
      api.get_fruit_by_name(conn, name: "apple-ei")
    magic.id
  }

  // First command tries to rename "apple-ei" → "banana-ei": UNIQUE violation.
  let result =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpdateFruitById(
        id: apple_id,
        name: Some("banana-ei"),
        color: None,
        price: None,
        quantity: None,
      ),
      cmd.UpsertFruitByName(
        name: "cherry-ei",
        color: None,
        price: None,
        quantity: None,
      ),
    ])
  let assert Error(#(0, _)) = result

  // "cherry-ei" must not exist: the executor stopped at the first failing batch.
  let assert Ok(None) = api.get_fruit_by_name(conn, name: "cherry-ei")

  let assert Ok(Nil) = sqlight.close(conn)
}

/// When the failing batch starts at index 2, the error carries index 2.
/// The first two commands (different variant, separate batch) succeed and
/// remain committed.
pub fn error_index_nonzero_test() {
  let conn = open_db()

  // Seed two fruits for the collision.
  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "fig-ei",
        color: Some("purple"),
        price: Some(4.0),
        quantity: Some(1),
      ),
      cmd.UpsertFruitByName(
        name: "grape-ei",
        color: Some("green"),
        price: Some(5.0),
        quantity: Some(2),
      ),
    ])

  let fig_id = {
    let assert Ok(Some(#(_, magic))) =
      api.get_fruit_by_name(conn, name: "fig-ei")
    magic.id
  }

  // Commands [0, 1] are UpsertFruitByName (batch starting at 0) — succeed.
  // Command [2] is UpdateFruitById (batch starting at 2) — fails: UNIQUE
  // violation because renaming "fig-ei" to existing "grape-ei".
  let result =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "new-a",
        color: None,
        price: None,
        quantity: None,
      ),
      cmd.UpsertFruitByName(
        name: "new-b",
        color: None,
        price: None,
        quantity: None,
      ),
      cmd.UpdateFruitById(
        id: fig_id,
        name: Some("grape-ei"),
        color: None,
        price: None,
        quantity: None,
      ),
    ])
  let assert Error(#(2, _)) = result

  // The first batch (index 0–1) committed: both new rows exist.
  let assert Ok(Some(_)) = api.get_fruit_by_name(conn, name: "new-a")
  let assert Ok(Some(_)) = api.get_fruit_by_name(conn, name: "new-b")

  // "fig-ei" was not renamed (batch at index 2 was rolled back).
  let assert Ok(Some(#(fig, _))) = api.get_fruit_by_id(conn, id: fig_id)
  let assert Some("fig-ei") = fig.name

  let assert Ok(Nil) = sqlight.close(conn)
}
