import case_studies/fruit_db/api
import case_studies/fruit_db/cmd
import gleam/list
import gleam/option.{Some}
import sqlight

pub fn fruit_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)

  let fruits = [
    #("apple", "red", 1.0, 1),
    #("banana", "yellow", 2.0, 2),
    #("cherry", "red", 3.0, 3),
    #("date", "brown", 4.0, 4),
    #("elderberry", "purple", 5.0, 5),
    #("fig", "purple", 6.0, 6),
    #("grape", "green", 7.0, 7),
    #("honeydew", "green", 8.0, 8),
    #("imbe", "red", 9.0, 9),
    #("jujube", "brown", 10.0, 10),
  ]

  list.each(fruits, fn(row) {
    let #(name, color, price, qty) = row
    let assert Ok(Nil) =
      api.execute_fruit_cmds(conn, [
        cmd.UpsertFruitByName(
          name: name,
          color: Some(color),
          price: Some(price),
          quantity: Some(qty),
        ),
      ])
  })
  // ensure the migration is not killing the data
  let assert Ok(Nil) = api.migrate(conn)

  let assert Ok(Some(#(_apple, magic))) =
    api.get_fruit_by_name(conn, name: "apple")
  let assert True = magic.id > 0
  let assert Ok(Some(#(_apple_by_id, magic_by_id))) =
    api.get_fruit_by_id(conn, id: magic.id)
  let assert True = magic_by_id.id == magic.id
  let assert Ok(Nil) = api.migrate(conn)

  let assert Ok(cheap) = api.query_cheap_fruit(conn, max_price: 5.5)
  let names_and_prices =
    list.map(cheap, fn(pair) {
      let #(f, _) = pair
      let assert Some(n) = f.name
      let assert Some(p) = f.price
      #(n, p)
    })

  let expected = [
    #("apple", 1.0),
    #("banana", 2.0),
    #("cherry", 3.0),
    #("date", 4.0),
    #("elderberry", 5.0),
  ]
  let assert True = names_and_prices == expected

  let assert Ok(Nil) = sqlight.close(conn)
}

pub fn fruit_batch_cmds_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)

  let cmds = [
    cmd.UpsertFruitByName(
      name: "kiwi",
      color: Some("green"),
      price: Some(11.0),
      quantity: Some(11),
    ),
    cmd.UpsertFruitByName(
      name: "lemon",
      color: Some("yellow"),
      price: Some(12.0),
      quantity: Some(12),
    ),
    cmd.UpsertFruitByName(
      name: "mango",
      color: Some("orange"),
      price: Some(13.0),
      quantity: Some(13),
    ),
  ]

  let assert Ok(Nil) = api.execute_fruit_cmds(conn, cmds)

  let assert Ok(Some(#(kiwi, _))) = api.get_fruit_by_name(conn, name: "kiwi")
  let assert Some("kiwi") = kiwi.name

  let assert Ok(Nil) = sqlight.close(conn)
}
