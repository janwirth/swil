import glance
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import schema_definition/edge_attributes
import schema_definition/entity
import schema_definition/identity
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}
import schema_definition/relationship_container
import schema_definition/scalar

pub type Classified {
  ScalarBucket(scalar.ScalarTypeDefinition)
  IdentitiesBucket(identity.IdentityTypeDefinition)
  EntityBucket(entity.EntityDefinition)
  RelationshipContainerBucket(relationship_container.RelationshipContainerDefinition)
  EdgeAttributesBucket(edge_attributes.RelationshipEdgeAttributesDefinition)
}

type ClassifyStep {
  Matched(Classified)
  Unmatched
}

/// Disambiguate a single public custom type into one hippo bucket (or error).
pub fn classify_strict(ct: glance.CustomType) -> Result(Classified, ParseError) {
  use _ <- result.try(require_no_type_parameters(ct))
  use _ <- result.try(require_at_least_one_variant(ct))
  try_scalar(ct)
  |> result.try(fn(step) {
    case step {
      Matched(c) -> Ok(c)
      Unmatched -> resolve_after_scalar_unmatched(ct)
    }
  })
}

fn require_no_type_parameters(ct: glance.CustomType) -> Result(Nil, ParseError) {
  case ct.parameters {
    [] -> Ok(Nil)
    _ ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "type "
          <> ct.name
          <> " must not have generic parameters in a squeal schema module",
      ))
  }
}

fn require_at_least_one_variant(ct: glance.CustomType) -> Result(Nil, ParseError) {
  case ct.variants {
    [] ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "public type "
          <> ct.name
          <> " has no variants; add at least one (for example empty variants for a scalar enum) or make the type `private` until it is defined",
      ))
    _ -> Ok(Nil)
  }
}

fn try_scalar(ct: glance.CustomType) -> Result(ClassifyStep, ParseError) {
  case scalar.try_shape(ct) {
    None -> Ok(Unmatched)
    Some(s) ->
      case string.ends_with(ct.name, "Scalar") {
        True -> Ok(Matched(ScalarBucket(s)))
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            "public scalar enum "
              <> ct.name
              <> " must end with `Scalar` (for example GenderScalar); types without that suffix that carry data on variants belong in a `*Identities` type referenced from an entity",
          ))
      }
  }
}

fn try_entity(ct: glance.CustomType) -> Result(ClassifyStep, ParseError) {
  case entity.try_parse(ct) {
    Ok(Some(e)) -> Ok(Matched(EntityBucket(e)))
    Ok(None) -> Ok(Unmatched)
    Error(e) -> Error(e)
  }
}

fn resolve_after_scalar_unmatched(
  ct: glance.CustomType,
) -> Result(Classified, ParseError) {
  case string.ends_with(ct.name, "Identities") {
    True ->
      identity.parse(ct)
      |> result.map(fn(i) { IdentitiesBucket(i) })
    False ->
      try_entity(ct)
      |> result.try(fn(step) {
        case step {
          Matched(c) -> Ok(c)
          Unmatched -> resolve_after_entity_unmatched(ct)
        }
      })
  }
}

fn resolve_after_entity_unmatched(
  ct: glance.CustomType,
) -> Result(Classified, ParseError) {
  case string.ends_with(ct.name, "Relationships") {
    True ->
      relationship_container.parse(ct)
      |> result.map(fn(r) { RelationshipContainerBucket(r) })
    False ->
      case string.ends_with(ct.name, "Attributes") {
        True ->
          edge_attributes.parse(ct)
          |> result.map(fn(a) { EdgeAttributesBucket(a) })
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            "public type "
              <> ct.name
              <> " is not a supported squeal shape (expected entity with required identities, optional relationships, *Identities, *Relationships, *Attributes, or payload-free enum ending in `Scalar`)",
          ))
      }
  }
}
