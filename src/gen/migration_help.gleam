import gleam/dynamic/decode
import gleam/list
import gleam/result
import sqlight

pub fn ensure_base_table(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use names <- result.try(pragma_table_info_names(conn))
  case names {
    [] ->
      sqlight.exec(
        "create table if not exists cats (id integer primary key, created_at int, updated_at int, deleted_at int);",
        conn,
      )
    _ -> Ok(Nil)
  }
}

pub fn ensure_column(
  conn: sqlight.Connection,
  column_name: String,
  alter_sql: String,
) -> Result(Nil, sqlight.Error) {
  use names <- result.try(pragma_table_info_names(conn))
  case list.contains(names, column_name) {
    True -> Ok(Nil)
    False -> sqlight.exec(alter_sql, conn)
  }
}

pub fn pragma_table_info_names(
  conn: sqlight.Connection,
) -> Result(List(String), sqlight.Error) {
  sqlight.query(
    "pragma table_info(cats)",
    conn,
    with: [],
    expecting: pragma_column_name_decoder(),
  )
}

fn pragma_column_name_decoder() -> decode.Decoder(String) {
  use name <- decode.field(1, decode.string)
  decode.success(name)
}
