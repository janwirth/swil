// Tests that make sure the ORM is working as expected - atm the orm is hand-coded
import cat_example.{
    cat_age_eq, cat_name_excludes, cat_older_than, cat_older_than_and_name_excludes,
}
import cat_db/entry as cats
import cat_db/resource.{Cat}
import cat_db/structure.{AgeField, CatRow, IdField}
import help/filter
import gleam/int
import gleam/list
import sqlight
import gleam/option.{None, Some}


pub fn cats_typed_schema_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = cats.cats(conn).migrate()
  let nubi =
    cats.cat_with_name("Nubi", Some(7))
  let whiskers =
    cats.cat_with_name("Whiskers", Some(3))
  let luna =
    cats.cat_with_name("Luna", Some(10))
  let assert Ok(_row) = cats.cats(conn).upsert_one(nubi)
  let assert Ok(_row) = cats.cats(conn).upsert_one(nubi)
  let assert Ok(_row) = cats.cats(conn).upsert_one(whiskers)
  let assert Ok(_row) = cats.cats(conn).upsert_one(luna)

  let assert Ok(rows) =
    cats.cats(conn).read_many(filter.FilterArg(filter: cat_older_than(6), sort: None))
  let assert [nubi_row, luna_row] = list.sort(rows, by: fn(a, b) {
    int.compare(a.id, b.id)
  })
  let assert CatRow(
    value: Cat(
      name: Some("Nubi"),
      age: Some(7),
    ),
    id: 1,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = nubi_row
  let assert CatRow(
    value: Cat(
      name: Some("Luna"),
      age: Some(10),
    ),
    id: 3,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = luna_row

  let assert Ok(rows) =
    cats.cats(conn).read_many(filter.FilterArg(filter: cat_older_than(8), sort: None))
  let assert [
    CatRow(
      value: Cat(
        name: Some("Luna"),
        age: Some(10),
      ),
      id: 3,
      created_at: 1,
      updated_at: 1,
      deleted_at: None,
    ),
  ] = rows

  let assert Ok(rows) =
    cats.cats(conn).read_many(filter.FilterArg(filter: cat_age_eq(3), sort: None))
  let assert [
    CatRow(
      value: Cat(
        name: Some("Whiskers"),
        age: Some(3),
      ),
      id: 2,
      created_at: 1,
      updated_at: 1,
      deleted_at: None,
    ),
  ] = rows

  let assert Ok(rows) =
    cats.cats(conn).read_many(filter.FilterArg(filter: cat_name_excludes("ubi"), sort: None))
  let assert [whiskers_row, luna_row2] = list.sort(rows, by: fn(a, b) {
    int.compare(a.id, b.id)
  })
  let assert CatRow(
    value: Cat(
      name: Some("Whiskers"),
      age: Some(3),
    ),
    id: 2,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = whiskers_row
  let assert CatRow(
    value: Cat(
      name: Some("Luna"),
      age: Some(10),
    ),
    id: 3,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = luna_row2

  let assert Ok(rows) =
    cats.cats(conn).read_many(filter.FilterArg(
      filter: cat_older_than_and_name_excludes(5, "isk"),
      sort: None,
    ))
  let assert [composite_nubi, composite_luna] = list.sort(rows, by: fn(a, b) {
    int.compare(a.id, b.id)
  })
  let assert CatRow(
    value: Cat(
      name: Some("Nubi"),
      age: Some(7),
    ),
    id: 1,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = composite_nubi
  let assert CatRow(
    value: Cat(
      name: Some("Luna"),
      age: Some(10),
    ),
    id: 3,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = composite_luna

  let assert Ok(sorted_by_age_desc) =
    cats.cats(conn).read_many(filter.NoFilter(sort: Some(filter.Desc(AgeField))))
  let assert [
    CatRow(
      value: Cat(name: Some("Luna"), age: Some(10)),
      id: 3,
      created_at: 1,
      updated_at: 1,
      deleted_at: None,
    ),
    CatRow(
      value: Cat(name: Some("Nubi"), age: Some(7)),
      id: 1,
      created_at: 1,
      updated_at: 1,
      deleted_at: None,
    ),
    CatRow(
      value: Cat(name: Some("Whiskers"), age: Some(3)),
      id: 2,
      created_at: 1,
      updated_at: 1,
      deleted_at: None,
    ),
  ] = sorted_by_age_desc

  let assert Ok(sorted_by_id_asc) =
    cats.cats(conn).read_many(filter.FilterArg(
      filter: cat_older_than(0),
      sort: Some(filter.Asc(IdField)),
    ))
  let assert [
    CatRow(
      value: Cat(name: Some("Nubi"), age: Some(7)),
      id: 1,
      created_at: 1,
      updated_at: 1,
      deleted_at: None,
    ),
    CatRow(
      value: Cat(name: Some("Whiskers"), age: Some(3)),
      id: 2,
      created_at: 1,
      updated_at: 1,
      deleted_at: None,
    ),
    CatRow(
      value: Cat(name: Some("Luna"), age: Some(10)),
      id: 3,
      created_at: 1,
      updated_at: 1,
      deleted_at: None,
    ),
  ] = sorted_by_id_asc
}

pub fn cats_migration_idempotent_three_times_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = cats.cats(conn).migrate()
  let assert Ok(Nil) = cats.cats(conn).migrate()
  let assert Ok(Nil) = cats.cats(conn).migrate()

  let nubi = cats.cat_with_name("Nubi", Some(7))
  let assert Ok(row) = cats.cats(conn).upsert_one(nubi)
  let assert CatRow(
    value: Cat(name: Some("Nubi"), age: Some(7)),
    id: 1,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = row
}

pub fn cats_update_one_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = cats.cats(conn).migrate()

  let assert Ok(inserted) =
    cats.cats(conn).upsert_one(cats.cat_with_name("Nubi", Some(7)))
  let assert Ok(Some(updated)) =
    cats.cats(conn).update_one(inserted.id, Cat(name: Some("Nubi"), age: Some(9)))

  let assert CatRow(
    value: Cat(name: Some("Nubi"), age: Some(9)),
    id: 1,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = updated
}

pub fn cats_update_many_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = cats.cats(conn).migrate()

  let assert Ok(r1) = cats.cats(conn).upsert_one(cats.cat_with_name("Nubi", Some(7)))
  let assert Ok(r2) = cats.cats(conn).upsert_one(cats.cat_with_name("Luna", Some(10)))

  let updates = [
    #(r1.id, Cat(name: Some("Nubi"), age: Some(8))),
    #(r2.id, Cat(name: Some("Luna"), age: Some(11))),
    #(999, Cat(name: Some("Ghost"), age: Some(1))),
  ]
  let assert Ok([Some(first), Some(second), None]) = cats.cats(conn).update_many(updates)

  let assert CatRow(
    value: Cat(name: Some("Nubi"), age: Some(8)),
    id: 1,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = first
  let assert CatRow(
    value: Cat(name: Some("Luna"), age: Some(11)),
    id: 2,
    created_at: 1,
    updated_at: 1,
    deleted_at: None,
  ) = second
}
