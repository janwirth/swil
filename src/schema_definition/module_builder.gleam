import glance
import gleam/list
import gleam/option.{None}
import gleam/result
import schema_definition/buckets
import schema_definition/classify
import schema_definition/entity
import schema_definition/identity
import schema_definition/parse_error.{
  type ParseError, UnsupportedSchema, hint_public_type_suffixes_or_entity,
}
import schema_definition/query
import schema_definition/schema_aggregate.{
  type SchemaDefinition, SchemaDefinition,
}

pub fn build_schema_strict(
  source: String,
  parsed: glance.Module,
) -> Result(SchemaDefinition, ParseError) {
  let custom_types_ordered = list.reverse(parsed.custom_types)
  let functions_ordered = list.reverse(parsed.functions)
  use buckets <- result.try(
    list.try_fold(custom_types_ordered, buckets.initial(), fn(acc, def) {
      case def {
        glance.Definition(_, ct) -> insert_custom_type_strict(source, acc, ct)
      }
    }),
  )
  use _ <- result.try(validate_identity_types_linked_to_entities(
    buckets.entities,
    buckets.identities,
  ))
  use queries <- result.try(query.extract_from_functions(functions_ordered))
  let predicate_functions = query.extract_predicate_functions(functions_ordered)
  Ok(SchemaDefinition(
    entities: list.reverse(buckets.entities),
    identities: list.reverse(buckets.identities),
    relationship_containers: list.reverse(buckets.relationship_containers),
    relationship_edge_attributes: list.reverse(
      buckets.relationship_edge_attributes,
    ),
    scalars: list.reverse(buckets.scalars),
    queries: queries,
    predicate_functions: predicate_functions,
  ))
}

fn insert_custom_type_strict(
  source: String,
  acc: buckets.Buckets,
  ct: glance.CustomType,
) -> Result(buckets.Buckets, ParseError) {
  case ct.publicity {
    glance.Private -> Ok(acc)
    glance.Public ->
      case classify.classify_strict(source, ct) {
        Ok(classified) -> Ok(buckets.insert_classified(acc, classified))
        Error(e) -> Error(e)
      }
  }
}

fn validate_identity_types_linked_to_entities(
  entities: List(entity.EntityDefinition),
  identities: List(identity.IdentityTypeDefinition),
) -> Result(Nil, ParseError) {
  let referenced =
    entities
    |> list.map(fn(e) { e.identity_type_name })
  use _ <- result.try(
    list.try_each(over: identities, with: fn(id) {
      case list.any(referenced, fn(r) { r == id.type_name }) {
        True -> Ok(Nil)
        False ->
          Error(UnsupportedSchema(
            None,
            [],
            "*Identities type "
              <> id.type_name
              <> " must be the `identities` field on a public entity in this module (or use a `*Scalar` enum for standalone sum types without an entity). "
              <> hint_public_type_suffixes_or_entity(),
          ))
      }
    }),
  )
  list.try_each(over: entities, with: fn(entity) {
    case
      list.any(identities, fn(id) { id.type_name == entity.identity_type_name })
    {
      True -> Ok(Nil)
      False ->
        Error(UnsupportedSchema(
          None,
          [],
          "entity "
            <> entity.type_name
            <> " references "
            <> entity.identity_type_name
            <> ", but that public *Identities type is not defined in this module",
        ))
    }
  })
}
