
import generator/migration as migration_generator
import simplifile

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

pub fn generate_full_from_path(path: String) -> GeneratedStructure {
    let assert Ok(module) = simplifile.read(path)
    generate_full(module)
}

pub fn generate_full(module: String) -> GeneratedStructure {
    // Build generated output from a schema module.
    // Until all generators are wired, use checked-in cat_db fixtures.
    let assert Ok(entry) = todo
    let assert Ok(resource) = todo
    let assert Ok(structure) = todo
    let assert Ok(crud) = todo
    let assert Ok(crud_sort) = todo
    let assert Ok(crud_filter) = todo
    let assert Ok(crud_delete) = todo
    let assert Ok(crud_read) = todo
    let assert Ok(crud_update) = todo
    let assert Ok(crud_upsert) = todo
    GeneratedStructure(
        migrate: migration_generator.generate(module, "idempotent"),

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
