import gleam/dynamic/decode
import sqlight

const insert_nubi_sql = "insert into cats (name) values ('Nubi');"
const read_nubi_sql = "select name from cats where name = 'Nubi';"

pub fn insert_nubi(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  sqlight.exec(insert_nubi_sql, conn)
}

pub fn read_nubi(conn: sqlight.Connection) -> Result(List(#(String)), sqlight.Error) {
  sqlight.query(read_nubi_sql, conn, with: [], expecting: row_decoder_name_only())
}

fn row_decoder_name_only() -> decode.Decoder(#(String)) {
  use name <- decode.field(0, decode.string)
  decode.success(#(name))
}
