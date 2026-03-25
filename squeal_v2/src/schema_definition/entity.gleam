import glance
import gleam/option.{type Option, None, Some}
import gleam/string
import schema_definition/fields.{
  type FieldDefinition, find_labelled_field, type_named_type_name,
  variant_fields_all_labelled, variant_fields_to_defs,
}
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}

/// Aggregate root: single record variant named like the type, with required `identities` and optional `relationships`.
pub type EntityDefinition {
  EntityDefinition(
    type_name: String,
    variant_name: String,
    fields: List(FieldDefinition),
    identity_type_name: String,
  )
}

pub fn try_parse(
  ct: glance.CustomType,
) -> Result(Option(EntityDefinition), ParseError) {
  case ct.variants {
    [glance.Variant(vname, vfields, _)] -> {
      case vname == ct.name {
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            "entity "
              <> ct.name
              <> " must use a variant constructor named `"
              <> ct.name
              <> "` (found `"
              <> vname
              <> "`); rename the variant to match the type for a table row",
          ))
        True ->
          case variant_fields_all_labelled(vfields) {
            False ->
              Error(UnsupportedSchema(
                Some(ct.location),
                "entity "
                  <> ct.name
                  <> " must use only labelled fields on its record variant",
              ))
            True ->
              case find_labelled_field(vfields, "identities") {
                None ->
                  case
                    string.ends_with(ct.name, "Attributes")
                    || string.ends_with(ct.name, "Relationships")
                  {
                    True -> Ok(None)
                    False ->
                      Error(UnsupportedSchema(
                        Some(ct.location),
                        ct.name
                          <> " has a record variant named like the type but no `identities` field; add `identities` pointing at a `*Identities` type, or use only empty variants for a scalar enum",
                      ))
                  }
                Some(#(_, id_type)) ->
                  case type_named_type_name(id_type) {
                    None ->
                      Error(UnsupportedSchema(
                        Some(ct.location),
                        "entity "
                          <> ct.name
                          <> " identities field must be a simple type name",
                      ))
                    Some(id_name) ->
                      case string.ends_with(id_name, "Identities") {
                        False ->
                          Error(UnsupportedSchema(
                            Some(ct.location),
                            "entity "
                              <> ct.name
                              <> " identities field must reference a *Identities type",
                          ))
                        True ->
                          case find_labelled_field(vfields, "relationships") {
                            None -> {
                              let fields = variant_fields_to_defs(vfields)
                              Ok(
                                Some(EntityDefinition(
                                  ct.name,
                                  vname,
                                  fields,
                                  id_name,
                                )),
                              )
                            }
                            Some(#(_, rel_type)) ->
                              case type_named_type_name(rel_type) {
                                None ->
                                  Error(UnsupportedSchema(
                                    Some(ct.location),
                                    "entity "
                                      <> ct.name
                                      <> " relationships field must be a simple type name",
                                  ))
                                Some(rel_name) ->
                                  case
                                    string.ends_with(rel_name, "Relationships")
                                  {
                                    False ->
                                      Error(UnsupportedSchema(
                                        Some(ct.location),
                                        "entity "
                                          <> ct.name
                                          <> " relationships field must reference a *Relationships type",
                                      ))
                                    True -> {
                                      let fields =
                                        variant_fields_to_defs(vfields)
                                      Ok(
                                        Some(EntityDefinition(
                                          ct.name,
                                          vname,
                                          fields,
                                          id_name,
                                        )),
                                      )
                                    }
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
    }
    _ -> Ok(None)
  }
}
