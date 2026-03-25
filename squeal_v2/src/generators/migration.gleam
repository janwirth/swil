import glance
import generators/sql_types
import gleam/list
import gleam/string
import schema_definition.{type EntityDefinition, type SchemaDefinition}

/// Applies [schema] to the database: drops tables from **other** versions first
/// (`drop_tables_not_in_schema` — e.g. `["animal"]` when migrating to fruit-only),
/// then creates each entity table and its identity indexes. Idempotent when re-run.
pub fn generate_migration(
  schema: SchemaDefinition,
  drop_tables_not_in_schema: List(String),
) -> String {
  let drops =
    list.map(drop_tables_not_in_schema, fn(t) {
      "drop table if exists " <> t <> ";"
    })
    |> string.join("\n")
  let creates =
    schema.entities
    |> list.map(fn(entity) { entity_ddl(schema, entity) })
    |> string.join("\n")
  case drops == "" {
    True -> creates
    False -> drops <> "\n" <> creates
  }
}

fn entity_table_name(entity_type: String) -> String {
  string.lowercase(entity_type)
}

fn type_is_list(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "List", _, _) -> True
    _ -> False
  }
}

/// Affinity spelling so `pragma table_info` matches INTEGER (not INT).
fn ddl_sql_type(type_: glance.Type) -> String {
  case sql_types.sql_type(type_) {
    "int" -> "integer"
    other -> other
  }
}

fn entity_ddl(schema: SchemaDefinition, entity: EntityDefinition) -> String {
  let assert Ok(identity_type) =
    list.find(schema.identities, fn(i) {
      i.type_name == entity.identity_type_name
    })
  let assert [variant, ..] = identity_type.variants
  let table = entity_table_name(entity.type_name)
  let data_fields =
    list.filter(entity.fields, fn(f) {
      f.label != "identities"
      && f.label != "relationships"
      && !type_is_list(f.type_)
    })
  let column_lines =
    list.map(data_fields, fn(f) {
      f.label <> " " <> ddl_sql_type(f.type_) <> " not null"
    })
  let all_columns =
    list.flatten([
      ["id integer primary key autoincrement not null"],
      column_lines,
      [
        "created_at integer not null",
        "updated_at integer not null",
        "deleted_at integer",
      ],
    ])
  let create_table =
    "create table if not exists "
    <> table
    <> " (\n  "
    <> string.join(all_columns, ",\n  ")
    <> "\n);"
  let cols =
    list.map(variant.fields, fn(f) { f.label })
    |> string.join(", ")
  let index_suffix =
    list.map(variant.fields, fn(f) { f.label })
    |> string.join("_")
  let index_name = table <> "_by_" <> index_suffix
  let create_index =
    "create unique index if not exists "
    <> index_name
    <> " on "
    <> table
    <> "("
    <> cols
    <> ");"
  create_table <> "\n" <> create_index
}
