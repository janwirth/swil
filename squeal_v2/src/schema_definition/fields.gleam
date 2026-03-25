import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import schema_definition/parse_error.{type ParseError, UnsupportedSchema}

pub type FieldDefinition {
  FieldDefinition(label: String, type_: glance.Type)
}

pub type VariantWithFields {
  VariantWithFields(variant_name: String, fields: List(FieldDefinition))
}

pub fn variant_fields_all_labelled(fields: List(glance.VariantField)) -> Bool {
  list.all(fields, fn(f) {
    case f {
      glance.LabelledVariantField(_, _) -> True
      glance.UnlabelledVariantField(_) -> False
    }
  })
}

pub fn find_labelled_field(
  fields: List(glance.VariantField),
  want: String,
) -> Option(#(String, glance.Type)) {
  case fields {
    [] -> None
    [glance.LabelledVariantField(t, label), ..rest] ->
      case label == want {
        True -> Some(#(label, t))
        False -> find_labelled_field(rest, want)
      }
    [glance.UnlabelledVariantField(_), ..rest] ->
      find_labelled_field(rest, want)
  }
}

pub fn type_named_type_name(t: glance.Type) -> Option(String) {
  case t {
    glance.NamedType(_, name, _, _) -> Some(name)
    _ -> None
  }
}

/// True for `String`, `Int`, `Float`, `Bool`, or `Date` with no type parameters.
/// Schema fields must not use these at the top level (wrap with `option.Option`).
pub fn type_is_unwrapped_primitive(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, name, _, []) ->
      case name {
        "String" | "Int" | "Float" | "Bool" | "Date" -> True
        _ -> False
      }
    _ -> False
  }
}

pub fn require_no_unwrapped_primitive_fields(
  fields: List(FieldDefinition),
  skip_labels: List(String),
  owning_type: String,
  location: glance.Span,
) -> Result(Nil, ParseError) {
  list.try_each(over: fields, with: fn(field) {
    case list.contains(skip_labels, field.label) {
      True -> Ok(Nil)
      False ->
        case type_is_unwrapped_primitive(field.type_) {
          False -> Ok(Nil)
          True ->
            Error(UnsupportedSchema(
              Some(location),
              "field `"
                <> field.label
                <> "` on "
                <> owning_type
                <> " must be nullable; wrap the type with `option.Option(...)` instead of a non-nullable primitive",
            ))
        }
    }
  })
}

pub fn variant_fields_to_defs(
  fields: List(glance.VariantField),
) -> List(FieldDefinition) {
  list.reverse(fields_to_defs_loop(fields, 1, []))
}

fn fields_to_defs_loop(
  fields: List(glance.VariantField),
  index: Int,
  acc: List(FieldDefinition),
) -> List(FieldDefinition) {
  case fields {
    [] -> acc
    [field, ..rest] -> {
      let pair = case field {
        glance.LabelledVariantField(item, label) -> FieldDefinition(label, item)
        glance.UnlabelledVariantField(item) ->
          FieldDefinition("field_" <> int.to_string(index), item)
      }
      fields_to_defs_loop(rest, index + 1, [pair, ..acc])
    }
  }
}
