import dog_db/crud/delete as crud_delete
import dog_db/crud/filter as crud_filter
import dog_db/crud/read as crud_read
import dog_db/crud/update as crud_update
import dog_db/crud/upsert as crud_upsert
import dog_db/migrate
import dog_db/resource.{type DogForUpsert}
import dog_db/structure.{
  type DogField, type DogsDb, type FilterableDog, type NumRefOrValue,
  type StringRefOrValue, DogsDb,
}
import dog_schema.{type Dog}
import gleam/option.{type Option}
import help/filter
import sqlight

pub type Filter =
  crud_filter.Filter

pub fn filter_arg(
  nullable_filter: Option(Filter),
  sort: Option(filter.SortOrder(DogField)),
) -> filter.FilterArg(FilterableDog, NumRefOrValue, StringRefOrValue, DogField) {
  crud_filter.filter_arg(nullable_filter, sort)
}

pub fn dogs(conn: sqlight.Connection) -> DogsDb {
  DogsDb(
    migrate: fn() { migrate.migrate_idempotent(conn) },
    upsert_one: fn(dog: DogForUpsert) { crud_upsert.upsert_one(conn, dog) },
    upsert_many: fn(rows: List(DogForUpsert)) {
      crud_upsert.upsert_many(conn, rows)
    },
    update_one: fn(id: Int, dog: Dog) { crud_update.update_one(conn, id, dog) },
    update_many: fn(rows: List(#(Int, Dog))) {
      crud_update.update_many(conn, rows)
    },
    read_one: fn(id: Int) { crud_read.read_one(conn, id) },
    read_many: fn(
      arg: filter.FilterArg(
        FilterableDog,
        NumRefOrValue,
        StringRefOrValue,
        DogField,
      ),
    ) {
      crud_read.read_many(conn, arg)
    },
    delete_one: fn(id: Int) { crud_delete.delete_one(conn, id) },
    delete_many: fn(ids: List(Int)) { crud_delete.delete_many(conn, ids) },
  )
}
