import gleam/dynamic/decode
import gleam/list
import gleam/result
import sqlight

pub fn ensure_base_table(
  conn: sqlight.Connection,
  table: String,
) -> Result(Nil, sqlight.Error) {
  use names <- result.try(pragma_table_info_names(conn, table))
  case names {
    [] ->
      sqlight.exec(
        "create table if not exists "
          <> table
          <> " (id integer primary key, created_at int, updated_at int, deleted_at int);",
        conn,
      )
    _ -> Ok(Nil)
  }
}

pub fn ensure_column(
  conn: sqlight.Connection,
  table: String,
  column_name: String,
  alter_sql: String,
) -> Result(Nil, sqlight.Error) {
  use names <- result.try(pragma_table_info_names(conn, table))
  case list.contains(names, column_name) {
    True -> Ok(Nil)
    False -> sqlight.exec(alter_sql, conn)
  }
}

pub fn pragma_table_info_names(
  conn: sqlight.Connection,
  table: String,
) -> Result(List(String), sqlight.Error) {
  sqlight.query(
    "pragma table_info(" <> table <> ")",
    conn,
    with: [],
    expecting: pragma_column_name_decoder(),
  )
}

fn pragma_column_name_decoder() -> decode.Decoder(String) {
  use name <- decode.field(1, decode.string)
  decode.success(name)
}
