import glance
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import schema_definition/fields.{
  type FieldDefinition, find_labelled_field, require_no_magic_field_labels,
  require_no_unwrapped_primitive_fields, type_named_type_name,
  variant_fields_all_labelled, variant_fields_to_defs,
}
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}

/// Parses custom types into entity definitions used by schema generation.
///
/// An entity must be a single record variant named like its type, include an
/// `identities` field pointing to `*Identities`, and may include a
/// `relationships` field pointing to `<EntityName>Relationships`.
/// Aggregate root: single record variant named like the type, with required `identities` and optional `relationships`.
pub type EntityDefinition {
  EntityDefinition(
    type_name: String,
    variant_name: String,
    fields: List(FieldDefinition),
    identity_type_name: String,
  )
}

/// Attempts to parse one custom type as an entity definition.
///
/// Returns `Ok(None)` for non-entity shapes (for example, sum types or multiple
/// variants), and `Error` when a type looks like an entity but violates entity
/// constraints.
pub fn try_parse(
  ct: glance.CustomType,
) -> Result(Option(EntityDefinition), ParseError) {
  case ct.variants {
    [variant] -> parse_single_variant(ct, variant)
    _ -> Ok(None)
  }
}

/// Parses and validates the one allowed variant shape for an entity.
fn parse_single_variant(
  ct: glance.CustomType,
  variant: glance.Variant,
) -> Result(Option(EntityDefinition), ParseError) {
  let glance.Variant(vname, vfields, _) = variant

  use _ <- result.try(require_variant_name_matches(ct, vname))
  use _ <- result.try(require_all_fields_labelled(ct, vfields))
  use id_name <- result.try(parse_identities_type_name(ct, vfields))
  use _ <- result.try(require_relationships_type_name_matches(ct, vfields))

  let fields = variant_fields_to_defs(vfields)
  use _ <- result.try(validate_non_magic_fields(ct, fields))

  Ok(Some(EntityDefinition(ct.name, vname, fields, id_name)))
}

/// Ensures the entity variant constructor name equals the type name.
fn require_variant_name_matches(
  ct: glance.CustomType,
  variant_name: String,
) -> Result(Nil, ParseError) {
  case variant_name == ct.name {
    True -> Ok(Nil)
    False ->
      Error(unsupported(
        ct,
        "entity "
          <> ct.name
          <> " must use a variant constructor named `"
          <> ct.name
          <> "` (found `"
          <> variant_name
          <> "`); rename the variant to match the type for a table row",
      ))
  }
}

/// Ensures all fields in the entity variant are labelled.
fn require_all_fields_labelled(
  ct: glance.CustomType,
  vfields: List(_),
) -> Result(Nil, ParseError) {
  case variant_fields_all_labelled(vfields) {
    True -> Ok(Nil)
    False ->
      Error(unsupported(
        ct,
        "entity "
          <> ct.name
          <> " must use only labelled fields on its record variant",
      ))
  }
}

/// Extracts and validates the `identities` field type name.
fn parse_identities_type_name(
  ct: glance.CustomType,
  vfields: List(_),
) -> Result(String, ParseError) {
  case find_labelled_field(vfields, "identities") {
    None ->
      Error(unsupported(
        ct,
        ct.name
          <> " has a record variant named like the type but no `identities` field; add `identities` pointing at a `*Identities` type",
      ))
    Some(#(_, id_type)) ->
      case type_named_type_name(id_type) {
        None ->
          Error(unsupported(
            ct,
            "entity " <> ct.name <> " identities field must be a simple type name",
          ))
        Some(id_name) ->
          case string.ends_with(id_name, "Identities") {
            True -> Ok(id_name)
            False ->
              Error(unsupported(
                ct,
                "entity "
                  <> ct.name
                  <> " identities field must reference a *Identities type",
              ))
          }
      }
  }
}

/// Validates the optional `relationships` field naming and shape.
fn require_relationships_type_name_matches(
  ct: glance.CustomType,
  vfields: List(_),
) -> Result(Nil, ParseError) {
  case find_labelled_field(vfields, "relationships") {
    None -> Ok(Nil)
    Some(#(_, rel_type)) ->
      case type_named_type_name(rel_type) {
        None ->
          Error(unsupported(
            ct,
            "entity " <> ct.name <> " relationships field must be a simple type name",
          ))
        Some(rel_name) ->
          case string.ends_with(rel_name, "Relationships") {
            False ->
              Error(unsupported(
                ct,
                "entity "
                  <> ct.name
                  <> " relationships field must reference a *Relationships type. "
                  <> "Use `relationships: "
                  <> ct.name
                  <> "Relationships`. "
                  <> "The Relationships type name must match the entity name.",
              ))
            True ->
              case rel_name == ct.name <> "Relationships" {
                True -> Ok(Nil)
                False ->
                  Error(unsupported(
                    ct,
                    "entity "
                      <> ct.name
                      <> " relationships field must be exactly `relationships: "
                      <> ct.name
                      <> "Relationships`. "
                      <> "The Relationships type name must match the entity name.",
                  ))
              }
          }
      }
  }
}

/// Runs field-level validation that is shared across all entity shapes.
fn validate_non_magic_fields(
  ct: glance.CustomType,
  fields: List(FieldDefinition),
) -> Result(Nil, ParseError) {
  use _ <- result.try(require_no_magic_field_labels(
    fields,
    ["identities", "relationships"],
    ct.name,
    ct.location,
  ))
  use _ <- result.try(require_no_unwrapped_primitive_fields(
    fields,
    ["identities", "relationships"],
    ct.name,
    ct.location,
  ))
  Ok(Nil)
}

/// Builds a parse error anchored to the custom type location.
fn unsupported(ct: glance.CustomType, message: String) -> ParseError {
  UnsupportedSchema(Some(ct.location), message)
}
