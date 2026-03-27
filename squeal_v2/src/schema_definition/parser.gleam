import glance
import glance_armstrong
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import schema_definition/edge_attributes as edge_attributes_mod
import schema_definition/entity as entity_mod
import schema_definition/fields as fields_mod
import schema_definition/identity as identity_mod
import schema_definition/module_builder
import schema_definition/parse_error as parse_error_mod
import schema_definition/query as query_mod
import schema_definition/relationship_container as relationship_container_mod
import schema_definition/scalar as scalar_mod
import schema_definition/schema_aggregate as schema_aggregate_mod
import schema_definition/schema_definition

pub fn parse_module(
  source: String,
) -> Result(schema_definition.SchemaDefinition, schema_definition.ParseError) {
  parse_module_strict(source)
  |> result.map(from_schema_aggregate)
  |> result.map_error(from_parse_error_mod)
}

pub fn format_parse_error(
  source: String,
  error: schema_definition.ParseError,
) -> String {
  case error {
    schema_definition.GlanceError(e) ->
      glance_armstrong.format_glance_parse_error(source, e)
    schema_definition.UnsupportedSchema(None, message) ->
      glance_armstrong.format_diagnostic_without_span(message)
    schema_definition.UnsupportedSchema(Some(span), message) ->
      glance_armstrong.format_source_diagnostic(source, span, message)
  }
}

fn parse_module_strict(
  source: String,
) -> Result(schema_aggregate_mod.SchemaDefinition, parse_error_mod.ParseError) {
  case glance.module(source) {
    Ok(parsed) -> module_builder.build_schema_strict(parsed)
    Error(e) -> Error(parse_error_mod.GlanceError(e))
  }
}

fn from_schema_aggregate(
  aggregate: schema_aggregate_mod.SchemaDefinition,
) -> schema_definition.SchemaDefinition {
  let schema_aggregate_mod.SchemaDefinition(
    entities: entities,
    identities: identities,
    relationship_containers: relationship_containers,
    relationship_edge_attributes: relationship_edge_attributes,
    scalars: scalars,
    queries: queries,
  ) = aggregate
  schema_definition.SchemaDefinition(
    entities: list.map(entities, from_entity),
    identities: list.map(identities, from_identity_type),
    relationship_containers: list.map(
      relationship_containers,
      from_relationship_container,
    ),
    relationship_edge_attributes: list.map(
      relationship_edge_attributes,
      from_relationship_edge_attributes,
    ),
    scalars: list.map(scalars, from_scalar),
    queries: list.map(queries, from_query_spec),
  )
}

fn from_entity(entity) -> schema_definition.EntityDefinition {
  let entity_mod.EntityDefinition(
    type_name: type_name,
    variant_name: variant_name,
    fields: fields,
    identity_type_name: identity_type_name,
  ) = entity
  schema_definition.EntityDefinition(
    type_name: type_name,
    variant_name: variant_name,
    fields: list.map(fields, from_field),
    identity_type_name: identity_type_name,
  )
}

fn from_field(field) -> schema_definition.FieldDefinition {
  let fields_mod.FieldDefinition(label: label, type_: type_) = field
  schema_definition.FieldDefinition(label:, type_:)
}

fn from_identity_type(identity_type) -> schema_definition.IdentityTypeDefinition {
  let identity_mod.IdentityTypeDefinition(
    type_name: type_name,
    variants: variants,
  ) = identity_type
  schema_definition.IdentityTypeDefinition(
    type_name: type_name,
    variants: list.map(variants, from_identity_variant),
  )
}

fn from_identity_variant(variant) -> schema_definition.IdentityVariantDefinition {
  let identity_mod.IdentityVariantDefinition(
    variant_name: variant_name,
    fields: fields,
  ) = variant
  schema_definition.IdentityVariantDefinition(
    variant_name: variant_name,
    fields: list.map(fields, from_field),
  )
}

fn from_variant_with_fields(variant) -> schema_definition.VariantWithFields {
  let fields_mod.VariantWithFields(variant_name: variant_name, fields: fields) =
    variant
  schema_definition.VariantWithFields(
    variant_name: variant_name,
    fields: list.map(fields, from_field),
  )
}

fn from_relationship_container(
  relationship_container,
) -> schema_definition.RelationshipContainerDefinition {
  let relationship_container_mod.RelationshipContainerDefinition(
    type_name: type_name,
    variants: variants,
  ) = relationship_container
  schema_definition.RelationshipContainerDefinition(
    type_name: type_name,
    variants: list.map(variants, from_variant_with_fields),
  )
}

fn from_relationship_edge_attributes(
  relationship_edge_attributes,
) -> schema_definition.RelationshipEdgeAttributesDefinition {
  let edge_attributes_mod.RelationshipEdgeAttributesDefinition(
    type_name: type_name,
    variants: variants,
  ) = relationship_edge_attributes
  schema_definition.RelationshipEdgeAttributesDefinition(
    type_name: type_name,
    variants: list.map(variants, from_variant_with_fields),
  )
}

fn from_scalar(scalar) -> schema_definition.ScalarTypeDefinition {
  let scalar_mod.ScalarTypeDefinition(
    type_name: type_name,
    variant_names: variant_names,
    enum_only: enum_only,
  ) = scalar
  schema_definition.ScalarTypeDefinition(type_name:, variant_names:, enum_only:)
}

fn from_query_spec(query_spec) -> schema_definition.QuerySpecDefinition {
  let query_mod.QuerySpecDefinition(
    name: name,
    parameters: parameters,
    query: query,
  ) = query_spec
  schema_definition.QuerySpecDefinition(
    name: name,
    parameters: list.map(parameters, from_query_parameter),
    query: query,
  )
}

fn from_query_parameter(parameter) -> schema_definition.QueryParameter {
  let query_mod.QueryParameter(label: label, name: name, type_: type_) =
    parameter
  schema_definition.QueryParameter(label:, name:, type_:)
}


fn from_parse_error_mod(
  error: parse_error_mod.ParseError,
) -> schema_definition.ParseError {
  case error {
    parse_error_mod.GlanceError(err) -> schema_definition.GlanceError(err)
    parse_error_mod.UnsupportedSchema(span: span, message: message) ->
      schema_definition.UnsupportedSchema(span:, message:)
  }
}
