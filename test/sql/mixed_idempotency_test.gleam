// Drives the hand-written example migration modules (blueprints for codegen): exclusive
// fruit vs animal vs hippo (+ human) versions, idempotent replays, and switching.
import assert_diff.{assert_diff}
import case_studies/example_migration_animal
import case_studies/fruit_db/migration as example_migration_fruit
import case_studies/hippo_db/migration as example_migration_hippo
import generators/migration/migration
import gleam/list
import schema_definition/parser as schema_parser
import simplifile
import sqlight

const schema2 = "
import gleam/option
pub type Animal {
    Animal(
        name: option.Option(String),
        species: option.Option(String),
        age: option.Option(Int),
        color: option.Option(String),
        identities: AnimalIdentities,
    )
}
pub type AnimalIdentities {
    ByName(name: String)
}
"

pub fn fruit_pragma_test() {
  let assert Ok(schema1) =
    simplifile.read("test/case_studies/fruit_schema.gleam")
  let assert Ok(fruit_expected) =
    simplifile.read("test/case_studies/fruit_db/migration.gleam")
  let assert Ok(fruit_def) = schema_parser.parse_module(schema1)
  let assert Ok(fruit_gleam) =
    migration.generate_pragma_migration_module(
      fruit_def,
      "case_studies/fruit_db/migration",
    )
  // let written_output = simplifile.write("test/case_studies/fruit_db/migration.gleam", fruit_gleam)
  assert_diff(fruit_expected, fruit_gleam)
}

pub fn animal_pragma_test() {
  let assert Ok(animal_expected) =
    simplifile.read("test/case_studies/example_migration_animal.gleam")
  let assert Ok(animal_def) = schema_parser.parse_module(schema2)
  let assert Ok(animal_gleam) =
    migration.generate_pragma_migration_module(
      animal_def,
      "case_studies/example_migration_animal",
    )
  // let written_output = simplifile.write("test/case_studies/example_migration_animal.gleam", animal_gleam)
  assert_diff(animal_expected, animal_gleam)
}

/// Junction-aware pragma migration matches the checked-in `library_manager_advanced_db/migration.gleam`.
pub fn library_manager_advanced_pragma_with_junctions_matches_disk_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/library_manager_advanced_schema.gleam")
  let assert Ok(expected) =
    simplifile.read(
      "test/case_studies/library_manager_advanced_db/migration.gleam",
    )
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(gleam) =
    migration.generate_pragma_migration_module_with_junctions(
      def,
      "case_studies/library_manager_advanced_db/migration",
    )
  assert_diff(expected, gleam)
}

/// Multi-entity pragma migration matches the checked-in `hippo_db/migration.gleam`.
pub fn hippo_pragma_codegen_matches_disk_test() {
  let assert Ok(src) = simplifile.read("test/case_studies/hippo_schema.gleam")
  let assert Ok(hippo_expected) =
    simplifile.read("test/case_studies/hippo_db/migration.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert True = list.length(def.entities) == 2
  let assert Ok(hippo_gleam) =
    migration.generate_pragma_migration_module(
      def,
      "case_studies/hippo_db/migration",
    )
  assert_diff(hippo_expected, hippo_gleam)
}

pub fn additive_item_v1_pragma_codegen_matches_disk_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/additive_item_v1_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("test/case_studies/additive_item_v1_db/migration.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(gleam) =
    migration.generate_pragma_migration_module(
      def,
      "case_studies/additive_item_v1_db/migration",
    )
  assert_diff(expected, gleam)
}

pub fn additive_item_v2_pragma_codegen_matches_disk_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/additive_item_v2_schema.gleam")
  let assert Ok(expected) =
    simplifile.read("test/case_studies/additive_item_v2_db/migration.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(gleam) =
    migration.generate_pragma_migration_module(
      def,
      "case_studies/additive_item_v2_db/migration",
    )
  assert_diff(expected, gleam)
}

pub fn imported_track_evolution_v0_pragma_codegen_matches_disk_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/imported_track_evolution_v0_schema.gleam")
  let assert Ok(expected) =
    simplifile.read(
      "test/case_studies/imported_track_evolution_v0_db/migration.gleam",
    )
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(gleam) =
    migration.generate_pragma_migration_module(
      def,
      "case_studies/imported_track_evolution_v0_db/migration",
    )
  assert_diff(expected, gleam)
}

pub fn imported_track_evolution_v1_pragma_codegen_matches_disk_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/imported_track_evolution_v1_schema.gleam")
  let assert Ok(expected) =
    simplifile.read(
      "test/case_studies/imported_track_evolution_v1_db/migration.gleam",
    )
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(gleam) =
    migration.generate_pragma_migration_module(
      def,
      "case_studies/imported_track_evolution_v1_db/migration",
    )
  assert_diff(expected, gleam)
}

pub fn imported_track_evolution_v2_pragma_codegen_matches_disk_test() {
  let assert Ok(src) =
    simplifile.read("test/case_studies/imported_track_evolution_v2_schema.gleam")
  let assert Ok(expected) =
    simplifile.read(
      "test/case_studies/imported_track_evolution_v2_db/migration.gleam",
    )
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert Ok(gleam) =
    migration.generate_pragma_migration_module(
      def,
      "case_studies/imported_track_evolution_v2_db/migration",
    )
  assert_diff(expected, gleam)
}

pub fn idempotent_migration_test() {
  let assert Ok(conn) = sqlight.open(":memory:")

  let assert Ok(Nil) = example_migration_fruit.migration(conn)
  let assert Ok(Nil) = example_migration_fruit.migration(conn)

  let assert Ok(Nil) = example_migration_animal.migration(conn)
  let assert Ok(Nil) = example_migration_animal.migration(conn)

  let assert Ok(Nil) = example_migration_fruit.migration(conn)
  let assert Ok(Nil) = example_migration_animal.migration(conn)

  let assert Ok(Nil) = example_migration_hippo.migration(conn)
  let assert Ok(Nil) = example_migration_hippo.migration(conn)

  let assert Ok(Nil) = example_migration_fruit.migration(conn)
  let assert Ok(Nil) = example_migration_hippo.migration(conn)

  let assert Ok(Nil) = example_migration_animal.migration(conn)
  let assert Ok(Nil) = example_migration_hippo.migration(conn)

  let assert Ok(Nil) = example_migration_fruit.migration(conn)
  let assert Ok(Nil) = example_migration_animal.migration(conn)

  let assert Ok(Nil) = sqlight.close(conn)
}
