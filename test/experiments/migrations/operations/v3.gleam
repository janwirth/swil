import gleam/dynamic/decode
import gleam/option.{type Option}
import sqlight

const insert_ginny_sql = "insert into cats (name, age, gender) values ('Ginny', 6, 'female');"

const update_ginny_gender_sql = "update cats set gender = 'male' where name = 'Ginny';"

const read_ginny_sql = "select name, age, gender from cats where name = 'Ginny';"

pub fn insert_ginny(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  sqlight.exec(insert_ginny_sql, conn)
}

pub fn update_ginny_gender(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  sqlight.exec(update_ginny_gender_sql, conn)
}

pub fn read_ginny(
  conn: sqlight.Connection,
) -> Result(List(#(String, Int, Option(String))), sqlight.Error) {
  sqlight.query(read_ginny_sql, conn, with: [], expecting: row_decoder_v3())
}

fn row_decoder_v3() -> decode.Decoder(#(String, Int, Option(String))) {
  use name <- decode.field(0, decode.string)
  use age <- decode.field(1, decode.int)
  use gender <- decode.field(2, decode.optional(decode.string))
  decode.success(#(name, age, gender))
}
