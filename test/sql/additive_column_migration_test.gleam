//// Nullable user columns: add a column after rows exist (no DEFAULT).
import gleam/dynamic/decode
import gleam/option.{None, Some}
import sqlight

pub fn add_column_after_insert_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) =
    sqlight.exec(
      "create table \"item\" (
  \"id\" integer primary key autoincrement not null,
  \"name\" text,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);",
      conn,
    )
  let assert Ok(Nil) =
    sqlight.exec(
      "insert into \"item\" (\"name\", \"created_at\", \"updated_at\") values ('alice', 1, 1);",
      conn,
    )
  let assert Ok(Nil) =
    sqlight.exec("alter table \"item\" add column \"age\" integer;", conn)
  let assert Ok(Nil) =
    sqlight.exec(
      "insert into \"item\" (\"name\", \"age\", \"created_at\", \"updated_at\") values ('bob', 30, 2, 2);",
      conn,
    )
  let assert Ok(rows) =
    sqlight.query(
      "select \"name\", \"age\" from \"item\" order by \"id\"",
      on: conn,
      with: [],
      expecting: {
        use name <- decode.field(0, decode.string)
        use age <- decode.field(1, decode.optional(decode.int))
        decode.success(#(name, age))
      },
    )
  let assert [#(n1, a1), #(n2, a2)] = rows
  let assert True = n1 == "alice"
  let assert True = a1 == None
  let assert True = n2 == "bob"
  let assert True = a2 == Some(30)
  let assert Ok(Nil) = sqlight.close(conn)
}
