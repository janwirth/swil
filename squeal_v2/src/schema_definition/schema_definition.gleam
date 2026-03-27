import glance
import gleam/option.{type Option}

pub type SchemaDefinition {
  SchemaDefinition(
    entities: List(EntityDefinition),
    identities: List(IdentityTypeDefinition),
    relationship_containers: List(RelationshipContainerDefinition),
    relationship_edge_attributes: List(RelationshipEdgeAttributesDefinition),
    scalars: List(ScalarTypeDefinition),
    queries: List(QuerySpecDefinition),
  )
}

pub type EntityDefinition {
  EntityDefinition(
    type_name: String,
    variant_name: String,
    fields: List(FieldDefinition),
    identity_type_name: String,
  )
}

pub type FieldDefinition {
  FieldDefinition(label: String, type_: glance.Type)
}

pub type IdentityTypeDefinition {
  IdentityTypeDefinition(
    type_name: String,
    variants: List(IdentityVariantDefinition),
  )
}

pub type IdentityVariantDefinition {
  IdentityVariantDefinition(variant_name: String, fields: List(FieldDefinition))
}

pub type VariantWithFields {
  VariantWithFields(variant_name: String, fields: List(FieldDefinition))
}

pub type RelationshipContainerDefinition {
  RelationshipContainerDefinition(
    type_name: String,
    variants: List(VariantWithFields),
  )
}

pub type RelationshipEdgeAttributesDefinition {
  RelationshipEdgeAttributesDefinition(
    type_name: String,
    variants: List(VariantWithFields),
  )
}

pub type ScalarTypeDefinition {
  ScalarTypeDefinition(
    type_name: String,
    variant_names: List(String),
    enum_only: Bool,
  )
}

pub type QuerySpecDefinition {
  QuerySpecDefinition(
    name: String,
    parameters: List(QueryParameter),
    codegen: QueryCodegen,
  )
}

pub type QueryCodegen {
  Unsupported
  LtMissingFieldAsc(
    column: String,
    threshold_param: String,
    shape_param: String,
  )
}

pub type QueryParameter {
  QueryParameter(label: Option(String), name: String, type_: glance.Type)
}

pub type QueryFunctionParameters {
  QueryFunctionParameters(
    entity: QueryEntityParameter,
    magic_fields: QueryMagicFieldsParameter,
    simple: QuerySimpleParameter,
  )
}

pub type QueryEntityParameter {
  QueryEntityParameter(name: String, type_name: String)
}

pub type QueryMagicFieldsParameter {
  QueryMagicFieldsParameter(name: String)
}

pub type QuerySimpleParameter {
  QuerySimpleParameter(name: String, type_: QuerySimpleType)
}

pub type QuerySimpleType {
  QuerySimpleInt
  QuerySimpleFloat
  QuerySimpleBool
  QuerySimpleString
}

pub type ParseError {
  GlanceError(glance.Error)
  UnsupportedSchema(span: Option(glance.Span), message: String)
}
