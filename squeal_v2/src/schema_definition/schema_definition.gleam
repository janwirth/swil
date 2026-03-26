import glance
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

/// Parsed view of a squeal schema module in the **hippo shape** only (see parser rules).
pub type SchemaDefinition =
  schema_aggregate_mod.SchemaDefinition

/// Aggregate root: single record variant named like the type, with required `identities` and optional `relationships`.
pub type EntityDefinition =
  entity_mod.EntityDefinition

pub type FieldDefinition =
  fields_mod.FieldDefinition

/// `*Identities` type: each variant is `By…` with labelled fields only.
pub type IdentityTypeDefinition =
  identity_mod.IdentityTypeDefinition

pub type IdentityVariantDefinition =
  identity_mod.IdentityVariantDefinition

pub type VariantWithFields =
  fields_mod.VariantWithFields

/// `*Relationships` type: single variant, same name as the type, labelled fields only.
pub type RelationshipContainerDefinition =
  relationship_container_mod.RelationshipContainerDefinition

/// `*Attributes` edge payload: single variant, same name as the type, labelled fields only.
pub type RelationshipEdgeAttributesDefinition =
  edge_attributes_mod.RelationshipEdgeAttributesDefinition

/// Name ends with `Scalar`: scalar (enum-like and/or record variant with fields); no `identities`.
pub type ScalarTypeDefinition =
  scalar_mod.ScalarTypeDefinition

/// Public function that returns `Query` (annotation or trailing `Query(...)`); parameters must be typed.
pub type QuerySpecDefinition =
  query_mod.QuerySpecDefinition

pub type QueryCodegen =
  query_mod.QueryCodegen

pub type QueryParameter =
  query_mod.QueryParameter

/// Render with [`format_parse_error`](#format_parse_error) / [`schema_diagnostics`](schema_diagnostics.html).
pub type ParseError =
  parse_error_mod.ParseError

/// Turn a [`ParseError`](#ParseError) into text using [`schema_diagnostics`](schema_diagnostics.html) (line + caret layout).
pub fn format_parse_error(source: String, error: ParseError) -> String {
  parse_error_mod.format_parse_error(source, error)
}

/// Parse a module **only** if every public custom type and public function fits the hippo-style rules.
pub fn parse_module(source: String) -> Result(SchemaDefinition, ParseError) {
  case glance.module(source) {
    Ok(parsed) -> module_builder.build_schema_strict(parsed)
    Error(e) -> Error(parse_error_mod.GlanceError(e))
  }
}
