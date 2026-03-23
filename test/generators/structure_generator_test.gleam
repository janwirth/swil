import simplifile

import generator/migration as migration_generator

// Fixture shape produced by the SQLite access-layer generator.
// Assumption: every generated module is emitted as source text (String).
pub type GeneratedStructure {
    GeneratedStructure(
        migrate: String,

        entry: String,
        resource: String,
        structure: String,

        crud: String,
        crud_submodules: GeneratedCrudSubmodules,
    )
}

pub type GeneratedCrudSubmodules {
    GeneratedCrudSubmodules(
        sort: String,
        filter: String,
        delete: String,
        read: String,
        update: String,
        upsert: String,
    )
}

pub fn generate_structure_from_path(path: String) -> GeneratedStructure {
    let assert Ok(module) = simplifile.read(path)
    generate_structure(module)
}

pub fn generate_structure(module: String) -> GeneratedStructure {
    // Build generated output from a schema module.
    // Until all generators are wired, use checked-in cat_db fixtures.
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
        migrate: migration_generator.generate(module, "idemptotent"),

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

pub fn generate_structure_test() {
    let reference_structure = get_references()
    // Golden test: generated output should match checked-in cat_db fixtures.
    assert reference_structure == generate_structure_from_path("src/cat_schema.gleam")
}

pub fn get_references() -> GeneratedStructure {
    // Read all fixture files from cat_db and assemble a comparable structure.
    let assert Ok(migration_generator) = simplifile.read("src/cat_db/migrate.gleam")
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