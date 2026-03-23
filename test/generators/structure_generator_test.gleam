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
        crud_sort: todo,
        crud_filter: todo,
        crud_delete: todo,
        crud_read: todo,
        crud_update: todo,
        crud_upsert: todo,
    )
}

pub fn get_references(module: String) -> GeneratedStructure {
    // read all files from cat_db and build generatedStructure from it
    let assert Ok(migration_generator) = simplifile.read("src/cat_db/migrate.gleam")
    let assert Ok(resource) = simplifile.read("src/cat_db/resource.gleam")
    let assert Ok(structure) = simplifile.read("src/cat_db/structure.gleam")
    let assert Ok(crud) = simplifile.read("src/cat_db/crud.gleam")
    let assert Ok(crud_sort) = simplifile.read("src/cat_db/crud_sort.gleam")
    let assert Ok(crud_filter) = simplifile.read("src/cat_db/crud_filter.gleam")
    let assert Ok(crud_delete) = simplifile.read("src/cat_db/crud_delete.gleam")
    let assert Ok(crud_read) = simplifile.read("src/cat_db/crud_read.gleam")
    let assert Ok(crud_update) = simplifile.read("src/cat_db/crud_update.gleam")
    let assert Ok(crud_upsert) = simplifile.read("src/cat_db/crud_upsert.gleam")
    
    GeneratedStructure(
        migrate: migration_generator,
        resource: resource,
        structure: structure,
        crud: crud,
        crud_sort: crud_sort,
        crud_filter: crud_filter,
        crud_delete: crud_delete,
        crud_read: crud_read,
        crud_update: crud_update,
        crud_upsert: crud_upsert,
    )
}