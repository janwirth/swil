import glance
import gleam/list
import gleam/option.{Some}
import gleam/result
import schema_definition/fields.{
  type FieldDefinition, type VariantWithFields, VariantWithFields,
  require_no_unwrapped_primitive_fields, variant_fields_all_labelled,
  variant_fields_to_defs,
}
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}

/// `*Relationships` type: single variant, same name as the type, labelled fields only.
pub type RelationshipContainerDefinition {
  RelationshipContainerDefinition(
    type_name: String,
    variants: List(VariantWithFields),
  )
}

pub fn parse(
  ct: glance.CustomType,
) -> Result(RelationshipContainerDefinition, ParseError) {
  case ct.variants {
    [glance.Variant(vname, vfields, _)] ->
      case vname == ct.name {
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            [],
            "*Relationships type "
              <> ct.name
              <> " must use a single variant of the same name",
          ))
        True ->
          case variant_fields_all_labelled(vfields) {
            False ->
              Error(UnsupportedSchema(
                Some(ct.location),
                [],
                "*Relationships " <> ct.name <> " must use only labelled fields",
              ))
            True -> {
              let field_defs = variant_fields_to_defs(vfields)
              use _ <- result.try(require_no_unwrapped_primitive_fields(
                field_defs,
                [],
                ct.name,
                ct.location,
              ))
              use _ <- result.try(require_valid_connection_shapes(
                field_defs,
                ct.name,
                ct.location,
              ))
              let v = VariantWithFields(vname, field_defs)
              Ok(RelationshipContainerDefinition(ct.name, [v]))
            }
          }
      }
    _ ->
      Error(UnsupportedSchema(
        Some(ct.location),
        [],
        "*Relationships type " <> ct.name <> " must have exactly one variant",
      ))
  }
}

fn require_valid_connection_shapes(
  fields: List(FieldDefinition),
  owning_type: String,
  location: glance.Span,
) -> Result(Nil, ParseError) {
  list.try_each(fields, fn(field) {
    case field.type_ {
      glance.NamedType(_, "Option", _, [inner]) ->
        reject_outer_optional_connection(inner, field.label, owning_type, location)
      glance.NamedType(_, "option.Option", _, [inner]) ->
        reject_outer_optional_connection(inner, field.label, owning_type, location)
      glance.NamedType(_, "BelongsTo", _, [first, _]) ->
        require_list_or_option_first_arg(first, field.label, owning_type, location, "BelongsTo")
      glance.NamedType(_, "dsl.BelongsTo", _, [first, _]) ->
        require_list_or_option_first_arg(first, field.label, owning_type, location, "BelongsTo")
      glance.NamedType(_, "Mutual", _, [first, _]) ->
        require_list_or_option_first_arg(first, field.label, owning_type, location, "Mutual")
      glance.NamedType(_, "dsl.Mutual", _, [first, _]) ->
        require_list_or_option_first_arg(first, field.label, owning_type, location, "Mutual")
      _ -> Ok(Nil)
    }
  })
}

fn reject_outer_optional_connection(
  inner: glance.Type,
  label: String,
  owning_type: String,
  location: glance.Span,
) -> Result(Nil, ParseError) {
  case inner {
    glance.NamedType(_, "BelongsTo", _, _)
    | glance.NamedType(_, "dsl.BelongsTo", _, _)
    | glance.NamedType(_, "Mutual", _, _)
    | glance.NamedType(_, "dsl.Mutual", _, _) ->
      Error(UnsupportedSchema(
        Some(location),
        [],
        "*Relationships field `"
          <> label
          <> "` on "
          <> owning_type
          <> " must not wrap connection types in option.Option(...); put List(...) or option.Option(...) inside BelongsTo/Mutual first argument",
      ))
    _ -> Ok(Nil)
  }
}

fn require_list_or_option_first_arg(
  first: glance.Type,
  label: String,
  owning_type: String,
  location: glance.Span,
  connection_name: String,
) -> Result(Nil, ParseError) {
  case first {
    glance.NamedType(_, "Option", _, [_]) -> Ok(Nil)
    glance.NamedType(_, "option.Option", _, [_]) -> Ok(Nil)
    glance.NamedType(_, "List", _, [_]) -> Ok(Nil)
    _ ->
        case first {
          _ ->
            Error(UnsupportedSchema(
              Some(location),
              [],
              "*Relationships field `"
                <> label
                <> "` on "
                <> owning_type
                <> " must use dsl."
                <> connection_name
                <> " with first type argument List(T) or option.Option(T)",
            ))
        }
  }
}
