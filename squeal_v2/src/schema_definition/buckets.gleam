import schema_definition/classify
import schema_definition/edge_attributes
import schema_definition/entity
import schema_definition/identity
import schema_definition/relationship_container
import schema_definition/scalar

pub type Buckets {
  Buckets(
    entities: List(entity.EntityDefinition),
    identities: List(identity.IdentityTypeDefinition),
    relationship_containers: List(
      relationship_container.RelationshipContainerDefinition,
    ),
    relationship_edge_attributes: List(
      edge_attributes.RelationshipEdgeAttributesDefinition,
    ),
    scalars: List(scalar.ScalarTypeDefinition),
  )
}

pub fn initial() -> Buckets {
  Buckets([], [], [], [], [])
}

pub fn insert_classified(
  acc: Buckets,
  classified: classify.Classified,
) -> Buckets {
  case classified {
    classify.ScalarBucket(s) -> Buckets(..acc, scalars: [s, ..acc.scalars])
    classify.IdentitiesBucket(i) ->
      Buckets(..acc, identities: [i, ..acc.identities])
    classify.EntityBucket(e) -> Buckets(..acc, entities: [e, ..acc.entities])
    classify.RelationshipContainerBucket(r) ->
      Buckets(..acc, relationship_containers: [r, ..acc.relationship_containers])
    classify.EdgeAttributesBucket(a) ->
      Buckets(..acc, relationship_edge_attributes: [
        a,
        ..acc.relationship_edge_attributes
      ])
  }
}
