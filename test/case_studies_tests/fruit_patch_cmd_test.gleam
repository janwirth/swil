/// E2E: `Patch*` leaves `option.None` columns unchanged; `Update*` still overwrites with sentinels.
/// Regression: optional fields use sentinel encoding on upsert (not SQL NULL), so unique keys behave.
import case_studies/fruit_db/api
import case_studies/fruit_db/cmd
import gleam/option.{None, Some}
import sqlight

fn open_db() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)
  conn
}

pub fn patch_by_id_leaves_none_unchanged_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "pear",
        color: Some("green"),
        price: Some(2.0),
        quantity: Some(3),
      ),
    ])
  let assert Ok(Some(#(_, magic))) =
    api.get_fruit_by_name(conn, name: "pear")

  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.PatchFruitById(
        id: magic.id,
        name: Some("pear"),
        color: None,
        price: Some(9.0),
        quantity: None,
      ),
    ])

  let assert Ok(Some(#(fruit, _))) =
    api.get_fruit_by_id(conn, id: magic.id)
  let assert Some("green") = fruit.color
  let assert Some(9.0) = fruit.price
  let assert Some(3) = fruit.quantity

  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn update_by_id_still_clears_optionals_with_sentinels_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "pear2",
        color: Some("green"),
        price: Some(2.0),
        quantity: Some(3),
      ),
    ])
  let assert Ok(Some(#(_, magic))) =
    api.get_fruit_by_name(conn, name: "pear2")

  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpdateFruitById(
        id: magic.id,
        name: Some("pear2"),
        color: None,
        price: Some(9.0),
        quantity: None,
      ),
    ])

  let assert Ok(Some(#(fruit, _))) =
    api.get_fruit_by_id(conn, id: magic.id)
  let assert None = fruit.color
  let assert Some(9.0) = fruit.price
  // `opt_int_for_db(None)` persists `0`; row decoder does not fold `0` back to `None`.
  let assert Some(0) = fruit.quantity

  let assert Ok(Nil) = sqlight.close(conn)
}

/// Sentinel empty string for missing optional text on upsert: still one row per name (not SQLite multi-NULL).
pub fn upsert_none_optional_does_not_fork_unique_name_test() {
  let conn = open_db()
  let assert Ok(Nil) =
    cmd.execute_fruit_cmds(conn, [
      cmd.UpsertFruitByName(
        name: "solo",
        color: None,
        price: None,
        quantity: None,
      ),
      cmd.UpsertFruitByName(
        name: "solo",
        color: Some("blue"),
        price: Some(1.0),
        quantity: Some(1),
      ),
    ])

  let assert Ok(Some(#(fruit, _))) =
    api.get_fruit_by_name(conn, name: "solo")
  let assert Some("blue") = fruit.color

  let assert Ok(Nil) = sqlight.close(conn)
}
