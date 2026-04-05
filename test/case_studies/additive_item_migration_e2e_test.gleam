//// v1: `ByNameAndAge` + migrate + upsert; v2: add `height`, canonical index `item_by_name`, upsert by name.
import case_studies/additive_item_v1_db/api as item_v1
import case_studies/additive_item_v1_db/cmd as item_v1_cmd
import case_studies/additive_item_v2_db/api as item_v2
import case_studies/additive_item_v2_db/cmd as item_v2_cmd
import gleam/option.{None, Some}
import sqlight

pub fn additive_item_schema_evolution_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = item_v1.migrate(conn)
  let assert Ok(Nil) =
    item_v1.execute_item_cmds(conn, [
      item_v1_cmd.UpsertItemByNameAndAge(name: "alice", age: 10),
    ])
  let assert Ok(Some(#(alice_v1, _))) =
    item_v1.get_item_by_name_and_age(conn, name: "alice", age: 10)
  let assert Some("alice") = alice_v1.name
  let assert Some(10) = alice_v1.age

  let assert Ok(Nil) = item_v2.migrate(conn)

  let assert Ok(Some(#(alice_v2, _))) =
    item_v2.get_item_by_name_and_age(conn, name: "alice", age: 10)
  let assert Some("alice") = alice_v2.name
  let assert Some(10) = alice_v2.age
  let assert True = alice_v2.height == None

  let assert Ok(Nil) =
    item_v2.execute_item_cmds(conn, [
      item_v2_cmd.UpsertItemByName(
        name: "bob",
        age: Some(20),
        height: Some(1.75),
      ),
    ])
  let assert Ok(Some(#(bob, _))) =
    item_v2.get_item_by_name(conn, name: "bob")
  let assert Some("bob") = bob.name
  let assert Some(20) = bob.age
  let assert Some(1.75) = bob.height

  let assert Ok(Some(#(bob_loaded, _))) =
    item_v2.get_item_by_name(conn, name: "bob")
  let assert True = bob_loaded.name == bob.name

  let assert Ok(Nil) = sqlight.close(conn)
}
