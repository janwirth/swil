import generators/api/api_decoders as dec
import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import schema_definition/schema_definition.{
  type EntityDefinition, type IdentityTypeDefinition,
  type ScalarTypeDefinition, type SchemaDefinition,
}

pub fn migration_import_path(schema_path: String) -> String {
  case string.split(schema_path, "/") {
    [] -> schema_path
    parts -> {
      let assert Ok(last) = list.last(parts)
      let n = list.length(parts)
      let prefix = list.take(parts, n - 1)
      let base = string.replace(last, "_schema", "")
      list.append(prefix, [base <> "_db", "migration"])
      |> string.join("/")
    }
  }
}

fn glance_type_referenced_names(t: glance.Type) -> List(String) {
  case t {
    glance.NamedType(_, name, _, params) ->
      list.append(
        [name],
        params
          |> list.map(glance_type_referenced_names)
          |> list.flatten,
      )
    glance.TupleType(_, els) ->
      els
      |> list.map(glance_type_referenced_names)
      |> list.flatten
    _ -> []
  }
}

fn uniq_sorted_strings(xs: List(String)) -> List(String) {
  list.sort(xs, string.compare)
  |> list.reverse
  |> list.fold([], fn(acc, x) {
    case acc {
      [y, ..] if x == y -> acc
      _ -> [x, ..acc]
    }
  })
  |> list.reverse
}

pub fn entity_used_scalar_type_names(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> List(String) {
  let scalar_type_names = list.map(def.scalars, fn(s) { s.type_name })
  let id = find_identity(def, entity)
  let from_fields =
    entity.fields
    |> list.filter(fn(f) {
      f.label != "identities" && f.label != "relationships"
    })
    |> list.flat_map(fn(f) { glance_type_referenced_names(f.type_) })
  let from_id =
    id.variants
    |> list.flat_map(fn(v) {
      v.fields
      |> list.flat_map(fn(f) { glance_type_referenced_names(f.type_) })
    })
  list.filter(list.append(from_fields, from_id), fn(n) {
    list.contains(scalar_type_names, n)
  })
  |> uniq_sorted_strings
}

fn entity_relationship_container_names(entity: EntityDefinition) -> List(String) {
  case list.find(entity.fields, fn(f) { f.label == "relationships" }) {
    Error(_) -> []
    Ok(f) ->
      case f.type_ {
        glance.NamedType(_, n, None, []) -> [n]
        glance.NamedType(_, n, Some(_), []) -> [n]
        _ -> []
      }
  }
}

/// Exposing list for a single-entity API module (first entity only): its types, referenced scalars,
/// identity variants — not other entities in the schema.
pub fn api_schema_exposing(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> String {
  let id = find_identity(def, entity)
  let scalar_names = entity_used_scalar_type_names(def, entity)
  let rel_names =
    entity_relationship_container_names(entity)
    |> list.sort(string.compare)
  let type_exports =
    list.flatten([
      list.map(scalar_names, fn(s) { "type " <> s }),
      ["type " <> entity.type_name],
      list.map(rel_names, fn(r) { "type " <> r }),
    ])
    |> list.sort(string.compare)
  let scalar_variants =
    def.scalars
    |> list.filter(fn(s) { list.contains(scalar_names, s.type_name) })
    |> list.flat_map(fn(s) { s.variant_names })
  let id_variant_names = list.map(id.variants, fn(v) { v.variant_name })
  let value_exports =
    list.flatten([
      id_variant_names,
      scalar_variants,
      [entity.type_name, ..rel_names],
    ])
    |> list.sort(string.compare)
  string.join(list.append(type_exports, value_exports), ", ")
}

pub fn import_alias(path: String) -> String {
  case string.split(path, "/") |> list.reverse() {
    [a, ..] -> a
    [] -> path
  }
}

pub fn find_identity(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> IdentityTypeDefinition {
  let assert Ok(id) =
    list.find(def.identities, fn(i) { i.type_name == entity.identity_type_name })
  id
}

pub fn schema_uses_calendar_date(def: SchemaDefinition) -> Bool {
  list.any(def.entities, fn(e) {
    list.any(e.fields, fn(f) { dec.field_is_calendar_date(f) })
    || {
      let id = find_identity(def, e)
      list.any(id.variants, fn(v) {
        list.any(v.fields, fn(f) { dec.field_is_calendar_date(f) })
      })
    }
  })
}

pub fn api_date_panic_label(schema_path: String) -> String {
  string.replace(import_alias(schema_path), "_schema", "_db/api")
  <> ": expected YYYY-MM-DD date string"
}

pub fn entity_used_enum_scalars(
  def: SchemaDefinition,
  entity: EntityDefinition,
) -> List(ScalarTypeDefinition) {
  let used = entity_used_scalar_type_names(def, entity)
  def.scalars
  |> list.filter(fn(s) {
    s.enum_only && list.contains(used, s.type_name)
  })
}
