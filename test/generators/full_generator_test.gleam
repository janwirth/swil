import generator/full.{
  type GeneratedStructure, GeneratedCrudSubmodules, GeneratedStructure,
  generate_full_from_path,
}
import simplifile

pub fn generate_full_test() {
  let reference_structure = get_references()
  // Golden test: generated output should match checked-in cat_db fixtures.
  assert reference_structure == generate_full_from_path("src/cat_schema.gleam")
}

pub fn get_references() -> GeneratedStructure {
  // Read all fixture files from cat_db and assemble a comparable structure.
  let assert Ok(migration_generator) =
    simplifile.read("src/cat_db/migrate.gleam")
  let assert Ok(entry) = simplifile.read("src/cat_db/entry.gleam")
  let assert Ok(resource) = simplifile.read("src/cat_db/resource.gleam")
  let assert Ok(structure) = simplifile.read("src/cat_db/structure.gleam")
  let assert Ok(crud) = simplifile.read("src/cat_db/crud.gleam")
  let assert Ok(crud_sort) = simplifile.read("src/cat_db/crud/sort.gleam")
  let assert Ok(crud_filter) = simplifile.read("src/cat_db/crud/filter.gleam")
  let assert Ok(crud_delete) = simplifile.read("src/cat_db/crud/delete.gleam")
  let assert Ok(crud_read) = simplifile.read("src/cat_db/crud/read.gleam")
  let assert Ok(crud_update) = simplifile.read("src/cat_db/crud/update.gleam")
  let assert Ok(crud_upsert) = simplifile.read("src/cat_db/crud/upsert.gleam")

  GeneratedStructure(
    migrate: migration_generator,
    entry: entry,
    resource: resource,
    structure: structure,
    crud: crud,
    crud_submodules: GeneratedCrudSubmodules(
      sort: crud_sort,
      filter: crud_filter,
      delete: crud_delete,
      read: crud_read,
      update: crud_update,
      upsert: crud_upsert,
    ),
  )
}
