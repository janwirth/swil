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
  RelationshipContainerBucket(
    relationship_container.RelationshipContainerDefinition,
  )
  EdgeAttributesBucket(edge_attributes.RelationshipEdgeAttributesDefinition)
}

type NameSuffix {
  SuffixIdentities
  SuffixRelationships
  SuffixAttributes
  SuffixScalar
  SuffixEntity
}

fn name_suffix(name: String) -> NameSuffix {
  case string.ends_with(name, "Identities") {
    True -> SuffixIdentities
    False ->
      case string.ends_with(name, "Relationships") {
        True -> SuffixRelationships
        False ->
          case string.ends_with(name, "Attributes") {
            True -> SuffixAttributes
            False ->
              case string.ends_with(name, "Scalar") {
                True -> SuffixScalar
                False -> SuffixEntity
              }
          }
      }
  }
}

/// Classify a public custom type by **name suffix**. `*Identities`, `*Relationships`, `*Attributes`,
/// and `*Scalar` are handled explicitly; anything else is parsed as an **entity** (aggregate with
/// `identities`, optional `relationships`).
pub fn classify_strict(ct: glance.CustomType) -> Result(Classified, ParseError) {
  use _ <- result.try(require_no_type_parameters(ct))
  use _ <- result.try(require_at_least_one_variant(ct))
  case name_suffix(ct.name) {
    SuffixIdentities -> identity.parse(ct) |> result.map(IdentitiesBucket)
    SuffixRelationships ->
      relationship_container.parse(ct)
      |> result.map(RelationshipContainerBucket)
    SuffixAttributes ->
      edge_attributes.parse(ct) |> result.map(EdgeAttributesBucket)
    SuffixScalar -> Ok(ScalarBucket(scalar.from_custom_type(ct)))
    SuffixEntity -> classify_entity_default(ct)
  }
}

fn classify_entity_default(
  ct: glance.CustomType,
) -> Result(Classified, ParseError) {
  case entity.try_parse(ct) {
    Ok(Some(e)) -> Ok(EntityBucket(e))
    Error(e) -> Error(e)
    Ok(None) ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "public type "
          <> ct.name
          <> " is not a squeal entity (expected a single record variant named like the type with a labelled `identities` field); for other shapes name the type with a `Scalar`, `Identities`, `Relationships`, or `Attributes` suffix",
      ))
  }
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

fn require_at_least_one_variant(
  ct: glance.CustomType,
) -> Result(Nil, ParseError) {
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
