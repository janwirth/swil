import cake/insert as cake_insert
import cake/select
import cake/update as cake_update
import cake/where
import cat_db/resource.{type CatForUpsert, CatWithName}
import cat_db/structure.{type CatRow, cat_row_decoder}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/time/timestamp
import help/cake_sql_exec
import sqlight

pub fn upsert_one(conn: sqlight.Connection, cat: CatForUpsert) -> Result(
  CatRow,
  sqlight.Error,
) {
  let #(stamp_sec, _) = timestamp.to_unix_seconds_and_nanoseconds(
    timestamp.system_time(),
  )
  case cat {
    CatWithName(name, age) -> {
      use _ <- result.try(
        cake_sql_exec.run_write_query(
          cake_insert.to_query(
            cake_insert.on_columns_conflict_update(
              cake_insert.source_values(
                cake_insert.columns(
                  cake_insert.table(cake_insert.new(), "cats"),
                  ["name", "age", "created_at", "updated_at", "deleted_at"],
                ),
                [cake_insert.row([cake_insert.string(name), case age {
                        Some(v) -> cake_insert.int(v)
                        None -> cake_insert.null()
                      }, cake_insert.int(stamp_sec), cake_insert.int(stamp_sec), cake_insert.null()])],
              ),
              ["name"],
              where.eq(where.int(1), where.int(1)),
              cake_update.set(
                cake_update.set(
                  cake_update.set(
                    cake_update.new(),
                    cake_update.set_expression("age", "excluded.age"),
                  ),
                  cake_update.set_expression(
                    "updated_at",
                    "excluded.updated_at",
                  ),
                ),
                cake_update.set_expression("deleted_at", "NULL"),
              ),
            ),
          ),
          decode.success(Nil),
          conn,
        ),
      )
      result.map(
        cake_sql_exec.run_read_query(
          select.to_query(
            select.where(
              select.select_cols(
                select.from_table(select.new(), "cats"),
                ["id", "created_at", "updated_at", "deleted_at", "name", "age"],
              ),
              where.and(
                [
                  where.eq(where.col("name"), where.string(name)),
                  where.is_null(where.col("deleted_at")),
                ],
              ),
            ),
          ),
          cat_row_decoder(),
          conn,
        ),
        fn(rows) { let assert [r] = rows r },
      )
    }
  }
}

pub fn upsert_many(conn: sqlight.Connection, rows: List(CatForUpsert)) -> Result(
  List(CatRow),
  sqlight.Error,
) {
  list.try_map(
    rows,
    fn(c: CatForUpsert)
    ->
    Result(CatRow, sqlight.Error)
    { upsert_one(conn, c) },
  )
}