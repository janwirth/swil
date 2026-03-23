import gleam/option.{type Option}
import sqlight

import cats_schema_generated/crud/delete as crud_delete
import cats_schema_generated/crud/filter as crud_filter
import cats_schema_generated/crud/read as crud_read
import cats_schema_generated/crud/upsert as crud_upsert
import cats_schema_generated/crud/update as crud_update
import cats_schema_generated/migrate
import cats_schema_generated/resource.{type Cat}
import cats_schema_generated/structure.{
  type CatField,
  type CatsDb,
  type FilterableCat,
  type NumRefOrValue,
  type StringRefOrValue,
  CatsDb,
}
import gen/filter

pub type Filter = crud_filter.Filter

pub fn filter_arg(
  nullable_filter: Option(Filter),
  sort: Option(filter.SortOrder(CatField)),
) -> filter.FilterArg(FilterableCat, NumRefOrValue, StringRefOrValue, CatField) {
  crud_filter.filter_arg(nullable_filter, sort)
}

pub fn cats(conn: sqlight.Connection) -> CatsDb {
  CatsDb(
    migrate: fn() { migrate.migrate_idemptotent(conn) },
    upsert_one: fn(cat: Cat) { crud_upsert.upsert_one(conn, cat) },
    upsert_many: fn(rows: List(Cat)) { crud_upsert.upsert_many(conn, rows) },
    update_one: fn(id: Int, cat: Cat) { crud_update.update_one(conn, id, cat) },
    update_many: fn(rows: List(#(Int, Cat))) { crud_update.update_many(conn, rows) },
    read_one: fn(id: Int) { crud_read.read_one(conn, id) },
    read_many: fn(arg: filter.FilterArg(
      FilterableCat,
      NumRefOrValue,
      StringRefOrValue,
      CatField,
    )) { crud_read.read_many(conn, arg) },
    delete_one: fn(id: Int) { crud_delete.delete_one(conn, id) },
    delete_many: fn(ids: List(Int)) { crud_delete.delete_many(conn, ids) },
  )
}
