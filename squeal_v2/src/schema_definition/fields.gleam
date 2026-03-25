import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

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
