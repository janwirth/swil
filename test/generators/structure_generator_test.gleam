import simplifile

import gen/migration_generator

pub type GeneratedStructure {
    GeneratedStructure(
        migrate: String,

        entry: String,
        resource: String,
        structure: String,

        crud: String,

        crud_sort: String,
        crud_filter: String,

        crud_delete: String,
        crud_read: String,
        crud_update: String,
        crud_upsert: String,

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