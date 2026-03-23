import gleam/dynamic/decode
import sqlight

const insert_biffy_sql = "insert into cats (name, age) values ('Biffy', 10);"

const update_biffy_age_sql = "update cats set age = 11 where name = 'Biffy';"

const read_biffy_sql = "select name, age from cats where name = 'Biffy';"

pub fn insert_biffy(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  sqlight.exec(insert_biffy_sql, conn)
}

pub fn update_biffy_age(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  sqlight.exec(update_biffy_age_sql, conn)
}

pub fn read_biffy(
  conn: sqlight.Connection,
) -> Result(List(#(String, Int)), sqlight.Error) {
  sqlight.query(read_biffy_sql, conn, with: [], expecting: row_decoder_v2())
}

fn row_decoder_v2() -> decode.Decoder(#(String, Int)) {
  use name <- decode.field(0, decode.string)
  use age <- decode.field(1, decode.int)
  decode.success(#(name, age))
}
