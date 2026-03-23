import simplifile

import gen/migration_generator

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
    GeneratedStructure(
        migrate: migration_generator.generate(module, "idemptotent"),

        entry: todo,
        resource: todo,
        structure: todo,

        crud: todo,
        crud_submodules: GeneratedCrudSubmodules(
            sort: todo,
            filter: todo,
            delete: todo,
            read: todo,
            update: todo,
            upsert: todo,
        ),
    )
}

// test

pub fn generate_structure_test() {
    let assert reference_structure = get_references()
    assert reference_structure == GeneratedStructure(
        migrate: migration_generator.generate("src/cat_schema.gleam", "idemptotent"),
        entry: todo,
        resource: todo,
        structure: todo,
        
        crud_submodules: todo,
        crud: todo
    )
}

pub fn get_references() -> GeneratedStructure {
    // read all files from cat_db and build generatedStructure from it
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