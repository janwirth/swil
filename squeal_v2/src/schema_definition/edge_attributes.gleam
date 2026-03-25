import glance
import gleam/option.{Some}
import schema_definition/fields.{
  type VariantWithFields, VariantWithFields, variant_fields_all_labelled,
  variant_fields_to_defs,
}
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}

/// `*Attributes` edge payload: single variant, same name as the type, labelled fields only.
pub type RelationshipEdgeAttributesDefinition {
  RelationshipEdgeAttributesDefinition(
    type_name: String,
    variants: List(VariantWithFields),
  )
}

pub fn parse(
  ct: glance.CustomType,
) -> Result(RelationshipEdgeAttributesDefinition, ParseError) {
  case ct.variants {
    [glance.Variant(vname, vfields, _)] ->
      case vname == ct.name {
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            "*Attributes type "
              <> ct.name
              <> " must use a single variant of the same name",
          ))
        True ->
          case variant_fields_all_labelled(vfields) {
            False ->
              Error(UnsupportedSchema(
                Some(ct.location),
                "*Attributes " <> ct.name <> " must use only labelled fields",
              ))
            True -> {
              let v = VariantWithFields(vname, variant_fields_to_defs(vfields))
              Ok(RelationshipEdgeAttributesDefinition(ct.name, [v]))
            }
          }
      }
    _ ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "*Attributes type " <> ct.name <> " must have exactly one variant",
      ))
  }
}
