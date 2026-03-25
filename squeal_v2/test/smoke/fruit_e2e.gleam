import case_studies/fruit_db/api
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/string
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
    let assert Ok(_) =
      api.upsert_fruit_by_name(conn, name, Some(color), Some(price), Some(qty))
  })

  let assert Ok(Some(#(apple, magic))) = api.get_fruit_by_name(conn, "apple")
  io.println("apple: " <> string.inspect(apple))
  let assert True = magic.id > 0

  let assert Ok(cheap) = api.query_cheap_fruit(conn, 5.5)
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
