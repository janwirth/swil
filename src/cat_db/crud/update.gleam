import cake/select
import cake/update as cake_update
import cake/where
import cat_db/structure.{type CatRow, cat_row_decoder}
import cat_schema.{type Cat}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import help/cake_sql_exec
import sqlight

pub fn update_one(conn: sqlight.Connection, id: Int, cat: cat_schema.Cat) -> Result(
  Option(CatRow),
  sqlight.Error,
) {
  use _ <- result.try({
      let #(now_sec, _) = timestamp.to_unix_seconds_and_nanoseconds(
        timestamp.system_time(),
      )
      cake_sql_exec.run_write_query(
        cake_update.to_query(cake_update.where(cake_update.set(case cat.age {
                Some(v) -> cake_update.set(case cat.name {
                    Some(v) -> cake_update.set(
                      cake_update.table(cake_update.new(), "cats"),
                      cake_update.set_string("name", v),
                    )
                    None -> cake_update.set(
                      cake_update.table(cake_update.new(), "cats"),
                      cake_update.set_null("name"),
                    )
                  }, cake_update.set_int("age", v))
                None -> cake_update.set(case cat.name {
                    Some(v) -> cake_update.set(
                      cake_update.table(cake_update.new(), "cats"),
                      cake_update.set_string("name", v),
                    )
                    None -> cake_update.set(
                      cake_update.table(cake_update.new(), "cats"),
                      cake_update.set_null("name"),
                    )
                  }, cake_update.set_null("age"))
              }, cake_update.set_int("updated_at", now_sec)), where.and(
              [
                where.eq(where.col("id"), where.int(id)),
                where.is_null(where.col("deleted_at")),
              ],
            ))),
        decode.success(Nil),
        conn,
      )
    })
  use rows <- result.try(
    cake_sql_exec.run_read_query(
      select.to_query(
        select.where(
          select.select_cols(
            select.from_table(select.new(), "cats"),
            ["id", "created_at", "updated_at", "deleted_at", "name", "age"],
          ),
          where.and(
            [
              where.eq(where.col("id"), where.int(id)),
              where.is_null(where.col("deleted_at")),
            ],
          ),
        ),
      ),
      cat_row_decoder(),
      conn,
    ),
  )
  case rows {
    [row, ..] -> Ok(Some(row))
    [] -> Ok(None)
  }
}

pub fn update_many(conn: sqlight.Connection, rows: List(#(Int, Cat))) -> Result(
  List(Option(CatRow)),
  sqlight.Error,
) {
  list.try_map(
    rows,
    fn(row: #(Int, Cat))
    ->
    Result(Option(CatRow), sqlight.Error)
    { let #(id, cat) = row
      update_one(conn, id, cat) },
  )
}