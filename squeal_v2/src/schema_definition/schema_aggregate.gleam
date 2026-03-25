import schema_definition/edge_attributes
import schema_definition/entity
import schema_definition/identity
import schema_definition/query
import schema_definition/relationship_container
import schema_definition/scalar

/// Parsed view of a squeal schema module in the **hippo shape** only (see parser rules).
pub type SchemaDefinition {
  SchemaDefinition(
    entities: List(entity.EntityDefinition),
    identities: List(identity.IdentityTypeDefinition),
    relationship_containers: List(relationship_container.RelationshipContainerDefinition),
    relationship_edge_attributes: List(
      edge_attributes.RelationshipEdgeAttributesDefinition,
    ),
    scalars: List(scalar.ScalarTypeDefinition),
    queries: List(query.QuerySpecDefinition),
  )
}
