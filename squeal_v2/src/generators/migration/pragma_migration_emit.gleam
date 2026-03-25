import generators/migration/pragma_migration_data.{type PragmaMigrationData}
import generators/migration/pragma_migration_module

/// Emits pragma migration Gleam source via gleamgen (`pragma_migration_module`).
pub fn emit(data: PragmaMigrationData) -> String {
  pragma_migration_module.build_and_render(data)
}
