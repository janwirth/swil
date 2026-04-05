/// Tests for HippoCommand / HumanCommand and their executors.
///
/// Covers: pure construction, round-trip for all variants, batch equivalence,
/// interleaved variant ordering, and error-index reporting via UNIQUE violation.
import case_studies/hippo_db/api
import case_studies/hippo_db/cmd
import case_studies/hippo_schema
import gleam/list
import gleam/option.{None, Some}
import gleam/time/calendar.{type Date, Date}
import sqlight

// ── Helpers ───────────────────────────────────────────────────────────────────

fn open_db() -> sqlight.Connection {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)
  conn
}

fn dob(year: Int, month: Int, day: Int) -> Date {
  let assert Ok(m) = calendar.month_from_int(month)
  Date(year, m, day)
}

// ── Pure construction ─────────────────────────────────────────────────────────

pub fn pure_construction_hippo_test() {
  let a =
    cmd.UpsertHippoByNameAndDateOfBirth(
      name: "Fiona",
      date_of_birth: dob(2010, 1, 5),
      gender: None,
    )
  let b =
    cmd.UpsertHippoByNameAndDateOfBirth(
      name: "Fiona",
      date_of_birth: dob(2010, 1, 5),
      gender: None,
    )
  let assert True = a == b

  let d =
    cmd.DeleteHippoByNameAndDateOfBirth(
      name: "Fiona",
      date_of_birth: dob(2010, 1, 5),
    )
  let assert True =
    d
    == cmd.DeleteHippoByNameAndDateOfBirth(
      name: "Fiona",
      date_of_birth: dob(2010, 1, 5),
    )

  let cmds = [a, d]
  let assert 2 = list.length(cmds)
}

pub fn pure_construction_human_test() {
  let a = cmd.UpsertHumanByEmail(email: "alice@example.com", name: Some("Alice"))
  let b = cmd.UpsertHumanByEmail(email: "alice@example.com", name: Some("Alice"))
  let assert True = a == b

  let del = cmd.DeleteHumanByEmail(email: "alice@example.com")
  let assert True = del == cmd.DeleteHumanByEmail(email: "alice@example.com")

  let u = cmd.UpdateHumanById(id: 7, name: Some("Alice B"), email: None)
  let assert True =
    u == cmd.UpdateHumanById(id: 7, name: Some("Alice B"), email: None)

  let cmds: List(cmd.HumanCommand) = [a, del, u]
  let assert 3 = list.length(cmds)
}

// ── Round-trip — hippo ────────────────────────────────────────────────────────

pub fn round_trip_hippo_upsert_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Bertha",
        date_of_birth: dob(2015, 3, 10),
        gender: None,
      ),
    ])
  let assert Ok(Some(#(hippo, _))) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Bertha",
      date_of_birth: dob(2015, 3, 10),
    )
  let assert Some("Bertha") = hippo.name
  let assert None = hippo.gender
  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_hippo_delete_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Gustav",
        date_of_birth: dob(2012, 7, 20),
        gender: None,
      ),
    ])
  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.DeleteHippoByNameAndDateOfBirth(
        name: "Gustav",
        date_of_birth: dob(2012, 7, 20),
      ),
    ])
  let assert Ok(None) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Gustav",
      date_of_birth: dob(2012, 7, 20),
    )
  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_hippo_update_by_key_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Nile",
        date_of_birth: dob(2008, 11, 3),
        gender: None,
      ),
    ])
  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpdateHippoByNameAndDateOfBirth(
        name: "Nile",
        date_of_birth: dob(2008, 11, 3),
        gender: Some(hippo_schema.Female),
      ),
    ])
  let assert Ok(Some(#(hippo, _))) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Nile",
      date_of_birth: dob(2008, 11, 3),
    )
  let assert Some(_) = hippo.gender
  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_hippo_update_by_id_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Congo",
        date_of_birth: dob(2019, 4, 15),
        gender: None,
      ),
    ])
  let assert Ok(Some(#(_, magic))) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Congo",
      date_of_birth: dob(2019, 4, 15),
    )
  let id = magic.id
  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpdateHippoById(
        id: id,
        name: Some("Congo"),
        gender: Some(hippo_schema.Male),
        date_of_birth: Some(dob(2019, 4, 15)),
      ),
    ])
  let assert Ok(Some(#(hippo, _))) = api.get_hippo_by_id(conn, id: id)
  let assert Some(_) = hippo.gender
  let assert Ok(Nil) = sqlight.close(conn)
}

// ── Round-trip — human ────────────────────────────────────────────────────────

pub fn round_trip_human_upsert_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.UpsertHumanByEmail(email: "bob@example.com", name: Some("Bob")),
    ])
  let assert Ok(Some(#(human, _))) =
    api.get_human_by_email(conn, email: "bob@example.com")
  let assert Some("Bob") = human.name
  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_human_delete_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.UpsertHumanByEmail(email: "carol@example.com", name: Some("Carol")),
    ])
  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.DeleteHumanByEmail(email: "carol@example.com"),
    ])
  let assert Ok(None) =
    api.get_human_by_email(conn, email: "carol@example.com")
  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_human_update_by_email_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.UpsertHumanByEmail(email: "dave@example.com", name: Some("Dave")),
    ])
  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.UpdateHumanByEmail(email: "dave@example.com", name: Some("David")),
    ])
  let assert Ok(Some(#(human, _))) =
    api.get_human_by_email(conn, email: "dave@example.com")
  let assert Some("David") = human.name
  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn round_trip_human_update_by_id_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.UpsertHumanByEmail(email: "eve@example.com", name: Some("Eve")),
    ])
  let assert Ok(Some(#(_, magic))) =
    api.get_human_by_email(conn, email: "eve@example.com")
  let id = magic.id
  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.UpdateHumanById(
        id: id,
        name: Some("Evelyn"),
        email: Some("eve@example.com"),
      ),
    ])
  let assert Ok(Some(#(human, _))) = api.get_human_by_id(conn, id: id)
  let assert Some("Evelyn") = human.name
  let assert Ok(Nil) = sqlight.close(conn)
}

// ── Batch equivalence ─────────────────────────────────────────────────────────

pub fn hippo_batch_same_as_sequential_test() {
  let conn_batch = open_db()
  let conn_seq = open_db()

  let cmds = [
    cmd.UpsertHippoByNameAndDateOfBirth(
      name: "Alpha",
      date_of_birth: dob(2001, 1, 1),
      gender: None,
    ),
    cmd.UpsertHippoByNameAndDateOfBirth(
      name: "Beta",
      date_of_birth: dob(2002, 2, 2),
      gender: None,
    ),
    cmd.UpsertHippoByNameAndDateOfBirth(
      name: "Gamma",
      date_of_birth: dob(2003, 3, 3),
      gender: None,
    ),
  ]

  let assert Ok(Nil) = cmd.execute_hippo_cmds(conn_batch, cmds)
  list.each(cmds, fn(c) {
    let assert Ok(Nil) = cmd.execute_hippo_cmds(conn_seq, [c])
  })

  let entries = [
    #("Alpha", dob(2001, 1, 1)),
    #("Beta", dob(2002, 2, 2)),
    #("Gamma", dob(2003, 3, 3)),
  ]
  list.each(entries, fn(pair) {
    let #(name, dob_val) = pair
    let assert Ok(Some(#(hb, _))) =
      api.get_hippo_by_name_and_date_of_birth(conn_batch, name: name, date_of_birth: dob_val)
    let assert Ok(Some(#(hs, _))) =
      api.get_hippo_by_name_and_date_of_birth(conn_seq, name: name, date_of_birth: dob_val)
    let assert True = hb.name == hs.name
  })

  let assert Ok(Nil) = sqlight.close(conn_batch)
  let assert Ok(Nil) = sqlight.close(conn_seq)
}

pub fn human_batch_same_as_sequential_test() {
  let conn_batch = open_db()
  let conn_seq = open_db()

  let cmds = [
    cmd.UpsertHumanByEmail(email: "u1@test.com", name: Some("User1")),
    cmd.UpsertHumanByEmail(email: "u2@test.com", name: Some("User2")),
    cmd.UpsertHumanByEmail(email: "u3@test.com", name: Some("User3")),
  ]

  let assert Ok(Nil) = cmd.execute_human_cmds(conn_batch, cmds)
  list.each(cmds, fn(c) {
    let assert Ok(Nil) = cmd.execute_human_cmds(conn_seq, [c])
  })

  list.each(["u1@test.com", "u2@test.com", "u3@test.com"], fn(email) {
    let assert Ok(Some(#(hb, _))) =
      api.get_human_by_email(conn_batch, email: email)
    let assert Ok(Some(#(hs, _))) =
      api.get_human_by_email(conn_seq, email: email)
    let assert True = hb.name == hs.name
  })

  let assert Ok(Nil) = sqlight.close(conn_batch)
  let assert Ok(Nil) = sqlight.close(conn_seq)
}

// ── Interleaved variants ──────────────────────────────────────────────────────

/// [UpsertByKey, UpdateById, UpsertByKey] — two batch lanes, all effects visible.
pub fn hippo_interleaved_variants_test() {
  let conn = open_db()

  // Seed so we have an id to update.
  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Zara",
        date_of_birth: dob(2017, 8, 8),
        gender: None,
      ),
    ])
  let assert Ok(Some(#(_, magic))) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Zara",
      date_of_birth: dob(2017, 8, 8),
    )
  let zara_id = magic.id

  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Nemo",
        date_of_birth: dob(2020, 5, 5),
        gender: None,
      ),
      // Different variant — flushes the previous batch, starts a new one.
      cmd.UpdateHippoById(
        id: zara_id,
        name: Some("Zara"),
        gender: Some(hippo_schema.Female),
        date_of_birth: Some(dob(2017, 8, 8)),
      ),
      // Back to UpsertByKey — third batch.
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Mara",
        date_of_birth: dob(2021, 6, 6),
        gender: None,
      ),
    ])

  let assert Ok(Some(_)) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Nemo",
      date_of_birth: dob(2020, 5, 5),
    )
  let assert Ok(Some(#(zara, _))) = api.get_hippo_by_id(conn, id: zara_id)
  let assert Some(hippo_schema.Female) = zara.gender
  let assert Ok(Some(_)) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Mara",
      date_of_birth: dob(2021, 6, 6),
    )

  let assert Ok(Nil) = sqlight.close(conn)
}

/// [Upsert, UpdateByEmail, Upsert] — human interleaved variants.
pub fn human_interleaved_variants_test() {
  let conn = open_db()

  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.UpsertHumanByEmail(email: "x@test.com", name: Some("X")),
      // Different variant — new batch.
      cmd.UpdateHumanByEmail(email: "x@test.com", name: Some("X2")),
      // Back to Upsert — third batch.
      cmd.UpsertHumanByEmail(email: "y@test.com", name: Some("Y")),
    ])

  let assert Ok(Some(#(x, _))) =
    api.get_human_by_email(conn, email: "x@test.com")
  let assert Some("X2") = x.name
  let assert Ok(Some(#(y, _))) =
    api.get_human_by_email(conn, email: "y@test.com")
  let assert Some("Y") = y.name

  let assert Ok(Nil) = sqlight.close(conn)
}

// ── Error index ───────────────────────────────────────────────────────────────

/// Failing batch at index 0: UNIQUE violation via UpdateHippoById trying to
/// adopt a composite key that another row already holds.
pub fn hippo_error_index_zero_test() {
  let conn = open_db()

  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "H-A",
        date_of_birth: dob(2000, 1, 1),
        gender: None,
      ),
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "H-B",
        date_of_birth: dob(2000, 1, 2),
        gender: None,
      ),
    ])

  let ha_id = {
    let assert Ok(Some(#(_, magic))) =
      api.get_hippo_by_name_and_date_of_birth(
        conn,
        name: "H-A",
        date_of_birth: dob(2000, 1, 1),
      )
    magic.id
  }

  // Command 0: UpdateById gives H-A the key of H-B → UNIQUE violation.
  let result =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpdateHippoById(
        id: ha_id,
        name: Some("H-B"),
        gender: None,
        date_of_birth: Some(dob(2000, 1, 2)),
      ),
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "H-C",
        date_of_birth: dob(2000, 1, 3),
        gender: None,
      ),
    ])
  let assert Error(#(0, _)) = result

  // H-C must not exist: executor stopped at failing batch 0.
  let assert Ok(None) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "H-C",
      date_of_birth: dob(2000, 1, 3),
    )

  let assert Ok(Nil) = sqlight.close(conn)
}

/// Batch at index 2 fails; batch at 0–1 stays committed.
pub fn hippo_error_index_nonzero_test() {
  let conn = open_db()

  let assert Ok(Nil) =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "River",
        date_of_birth: dob(2005, 5, 5),
        gender: None,
      ),
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Lake",
        date_of_birth: dob(2005, 5, 6),
        gender: None,
      ),
    ])

  let river_id = {
    let assert Ok(Some(#(_, magic))) =
      api.get_hippo_by_name_and_date_of_birth(
        conn,
        name: "River",
        date_of_birth: dob(2005, 5, 5),
      )
    magic.id
  }

  // [0,1]: UpsertByKey batch → succeed.
  // [2]:   UpdateById batch  → UNIQUE violation (Lake key taken).
  let result =
    cmd.execute_hippo_cmds(conn, [
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Sea",
        date_of_birth: dob(2006, 6, 1),
        gender: None,
      ),
      cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Ocean",
        date_of_birth: dob(2006, 6, 2),
        gender: None,
      ),
      cmd.UpdateHippoById(
        id: river_id,
        name: Some("Lake"),
        gender: None,
        date_of_birth: Some(dob(2005, 5, 6)),
      ),
    ])
  let assert Error(#(2, _)) = result

  // Batch 0–1 committed.
  let assert Ok(Some(_)) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Sea",
      date_of_birth: dob(2006, 6, 1),
    )
  let assert Ok(Some(_)) =
    api.get_hippo_by_name_and_date_of_birth(
      conn,
      name: "Ocean",
      date_of_birth: dob(2006, 6, 2),
    )
  // River not renamed (batch 2 rolled back).
  let assert Ok(Some(#(river, _))) = api.get_hippo_by_id(conn, id: river_id)
  let assert Some("River") = river.name

  let assert Ok(Nil) = sqlight.close(conn)
}

/// Human UNIQUE violation on email at index 0.
pub fn human_error_index_test() {
  let conn = open_db()

  let assert Ok(Nil) =
    cmd.execute_human_cmds(conn, [
      cmd.UpsertHumanByEmail(email: "p1@test.com", name: Some("P1")),
      cmd.UpsertHumanByEmail(email: "p2@test.com", name: Some("P2")),
    ])

  let p1_id = {
    let assert Ok(Some(#(_, magic))) =
      api.get_human_by_email(conn, email: "p1@test.com")
    magic.id
  }

  // UpdateById tries to give p1 the email of p2 → UNIQUE violation at index 0.
  let result =
    cmd.execute_human_cmds(conn, [
      cmd.UpdateHumanById(
        id: p1_id,
        name: Some("P1"),
        email: Some("p2@test.com"),
      ),
      cmd.UpsertHumanByEmail(email: "p3@test.com", name: Some("P3")),
    ])
  let assert Error(#(0, _)) = result

  // p3 must not exist.
  let assert Ok(None) = api.get_human_by_email(conn, email: "p3@test.com")

  let assert Ok(Nil) = sqlight.close(conn)
}
