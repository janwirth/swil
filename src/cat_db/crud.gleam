import cat_db/crud/delete as crud_delete
import cat_db/crud/filter as crud_filter
import cat_db/crud/read as crud_read
import cat_db/crud/update as crud_update
import cat_db/crud/upsert as crud_upsert
import cat_db/migrate
import cat_db/resource.{type CatForUpsert}
import cat_db/structure.{
  type CatField, type CatsDb, type FilterableCat, type NumRefOrValue,
  type StringRefOrValue, CatsDb,
}
import cat_schema.{type Cat}
import gleam/option.{type Option}
import help/filter
import sqlight

pub type Filter =
  crud_filter.Filter

pub fn filter_arg(
  nullable_filter: Option(Filter),
  sort: Option(filter.SortOrder(CatField)),
) -> filter.FilterArg(FilterableCat, NumRefOrValue, StringRefOrValue, CatField) {
  crud_filter.filter_arg(nullable_filter, sort)
}

pub fn cats(conn: sqlight.Connection) -> CatsDb {
  CatsDb(
    migrate: fn() { migrate.migrate_idempotent(conn) },
    upsert_one: fn(cat: CatForUpsert) { crud_upsert.upsert_one(conn, cat) },
    upsert_many: fn(rows: List(CatForUpsert)) {
      crud_upsert.upsert_many(conn, rows)
    },
    update_one: fn(id: Int, cat: Cat) { crud_update.update_one(conn, id, cat) },
    update_many: fn(rows: List(#(Int, Cat))) {
      crud_update.update_many(conn, rows)
    },
    read_one: fn(id: Int) { crud_read.read_one(conn, id) },
    read_many: fn(
      arg: filter.FilterArg(
        FilterableCat,
        NumRefOrValue,
        StringRefOrValue,
        CatField,
      ),
    ) {
      crud_read.read_many(conn, arg)
    },
    delete_one: fn(id: Int) { crud_delete.delete_one(conn, id) },
    delete_many: fn(ids: List(Int)) { crud_delete.delete_many(conn, ids) },
  )
}
