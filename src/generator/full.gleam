
import generator/crud as crud_generator
import generator/crud_delete as crud_delete_generator
import generator/crud_filter as crud_filter_generator
import generator/crud_read as crud_read_generator
import generator/crud_sort as crud_sort_generator
import generator/crud_update as crud_update_generator
import generator/crud_upsert as crud_upsert_generator
import generator/entry as entry_generator
import generator/migration as migration_generator
import generator/resource as resource_generator
import generator/schema_context
import generator/structure as structure_generator
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
    let assert Ok(ctx) = schema_context.parse(module)
    GeneratedStructure(
        migrate: migration_generator.generate(module, "idempotent"),

        entry: entry_generator.generate(ctx),
        resource: resource_generator.generate(ctx),
        structure: structure_generator.generate(ctx),

        crud: crud_generator.generate(ctx),
        crud_submodules: GeneratedCrudSubmodules(
            sort: crud_sort_generator.generate(ctx),
            filter: crud_filter_generator.generate(ctx),
            delete: crud_delete_generator.generate(ctx),
            read: crud_read_generator.generate(ctx),
            update: crud_update_generator.generate(ctx),
            upsert: crud_upsert_generator.generate(ctx),
        ),
    )
}
