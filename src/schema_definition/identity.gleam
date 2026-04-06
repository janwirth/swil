/// Identities are ash-inspired - mention multiple fields that will get a unique constraint.
/// An entity can have multiple identities, and an identity can have multiple fields.
/// Examples:
/// - ByNameAndAge(name: String, age: Int)
/// - ByEmail(email: String)
import glance
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import schema_definition/fields.{
  type FieldDefinition, variant_fields_all_labelled, variant_fields_to_defs,
}
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}

/// `*Identities` type: each variant is `By…` with labelled fields only.
pub type IdentityTypeDefinition {
  IdentityTypeDefinition(
    type_name: String,
    variants: List(IdentityVariantDefinition),
  )
}

pub type IdentityVariantDefinition {
  IdentityVariantDefinition(variant_name: String, fields: List(FieldDefinition))
}

pub fn parse(
  ct: glance.CustomType,
) -> Result(IdentityTypeDefinition, ParseError) {
  case ct.variants {
    [] ->
      Error(UnsupportedSchema(
        Some(ct.location),
        [],
        "identities type " <> ct.name <> " must declare at least one variant",
      ))
    variants -> {
      use _ <- result.try(
        list.try_fold(variants, Nil, fn(_, v) {
          case v.name == "ById" {
            True ->
              Error(UnsupportedSchema(
                Some(ct.location),
                [],
                "identity variant ById in "
                  <> ct.name
                  <> " is reserved for internal row id lookup; choose a different identity name",
              ))
            False ->
              case string.starts_with(v.name, "By") {
                False ->
                  Error(UnsupportedSchema(
                    Some(ct.location),
                    [],
                    "identity variant "
                      <> v.name
                      <> " in "
                      <> ct.name
                      <> " must start with `By`",
                  ))
                True ->
                  case variant_fields_all_labelled(v.fields) {
                    False ->
                      Error(UnsupportedSchema(
                        Some(ct.location),
                        [],
                        "identity variant "
                          <> v.name
                          <> " must use only labelled fields",
                      ))
                    True -> Ok(Nil)
                  }
              }
          }
        }),
      )
      let defs =
        list.map(variants, fn(v) {
          IdentityVariantDefinition(v.name, variant_fields_to_defs(v.fields))
        })
      Ok(IdentityTypeDefinition(ct.name, defs))
    }
  }
}
