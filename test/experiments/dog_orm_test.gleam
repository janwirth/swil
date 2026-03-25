// ORM integration tests: use `bun run test` so `dog_db` is regenerated before `gleam test` compiles.
import dog_db/crud as dogs_crud
import dog_db/entry as dogs
import dog_db/structure.{DogRow, IntVal}
import dog_schema.{Dog}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import help/filter
import sqlight

pub fn dogs_migration_idempotent_three_times_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = dogs.dogs(conn).migrate()
  let assert Ok(Nil) = dogs.dogs(conn).migrate()
  let assert Ok(Nil) = dogs.dogs(conn).migrate()

  let assert Ok(row) =
    dogs.dogs(conn).upsert_one(dogs.dog_with_name_is_neutered(
      "Rex",
      True,
      Some(5),
    ))
  let assert DogRow(
    value: Dog(name: Some("Rex"), age: Some(5), is_neutered: Some(True)),
    id: 1,
    created_at: _,
    updated_at: _,
    deleted_at: None,
  ) = row
}

pub fn dogs_filter_by_neutered_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = dogs.dogs(conn).migrate()

  let assert Ok(_row) =
    dogs.dogs(conn).upsert_one(dogs.dog_with_name_is_neutered(
      "Rex",
      True,
      Some(5),
    ))
  let assert Ok(_row) =
    dogs.dogs(conn).upsert_one(dogs.dog_with_name_is_neutered(
      "Bolt",
      False,
      Some(3),
    ))
  let assert Ok(_row) =
    dogs.dogs(conn).upsert_one(dogs.dog_with_name_is_neutered(
      "Luna",
      True,
      Some(2),
    ))

  let only_neutered =
    dogs_crud.filter_arg(
      Some(fn(dog: dogs.FilterableDog) {
        filter.Eq(left: dog.is_neutered, right: IntVal(value: 1))
      }),
      None,
    )
  let assert Ok(rows) = dogs.dogs(conn).read_many(only_neutered)
  let assert [rex_row, luna_row] =
    list.sort(rows, by: fn(a, b) { int.compare(a.id, b.id) })

  let assert DogRow(
    value: Dog(name: Some("Rex"), age: Some(5), is_neutered: Some(True)),
    id: 1,
    created_at: _,
    updated_at: _,
    deleted_at: None,
  ) = rex_row
  let assert DogRow(
    value: Dog(name: Some("Luna"), age: Some(2), is_neutered: Some(True)),
    id: 3,
    created_at: _,
    updated_at: _,
    deleted_at: None,
  ) = luna_row
}

pub fn dogs_upsert_composite_identity_test() {
  use conn <- sqlight.with_connection(":memory:")
  let assert Ok(Nil) = dogs.dogs(conn).migrate()

  // identity is (name, is_neutered), so this is an update
  let assert Ok(first) =
    dogs.dogs(conn).upsert_one(dogs.dog_with_name_is_neutered(
      "Rex",
      True,
      Some(5),
    ))
  let assert Ok(updated_same_identity) =
    dogs.dogs(conn).upsert_one(dogs.dog_with_name_is_neutered(
      "Rex",
      True,
      Some(6),
    ))
  // same name, different neutered flag -> distinct row
  let assert Ok(second_identity) =
    dogs.dogs(conn).upsert_one(dogs.dog_with_name_is_neutered(
      "Rex",
      False,
      Some(4),
    ))

  let assert True = first.id == updated_same_identity.id
  let assert True = first.id == 1
  let assert True = second_identity.id == 2
  let assert True =
    updated_same_identity.value
    == Dog(name: Some("Rex"), age: Some(6), is_neutered: Some(True))

  let assert Ok(all_rows) =
    dogs.dogs(conn).read_many(dogs_crud.filter_arg(None, None))
  let assert [row1, row2] =
    list.sort(all_rows, by: fn(a, b) { int.compare(a.id, b.id) })
  let assert DogRow(
    value: Dog(name: Some("Rex"), age: Some(6), is_neutered: Some(True)),
    id: 1,
    created_at: _,
    updated_at: _,
    deleted_at: None,
  ) = row1
  let assert DogRow(
    value: Dog(name: Some("Rex"), age: Some(4), is_neutered: Some(False)),
    id: 2,
    created_at: _,
    updated_at: _,
    deleted_at: None,
  ) = row2
}
