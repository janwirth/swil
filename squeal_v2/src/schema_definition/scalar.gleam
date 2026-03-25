import glance
import gleam/list
import gleam/option.{type Option, None, Some}

/// Enum-like: every variant has no payloads; at least one variant.
pub type ScalarTypeDefinition {
  ScalarTypeDefinition(type_name: String, variant_names: List(String))
}

/// Shape only: payload-free variants (name / `Scalar` suffix validated in classify pipeline).
pub fn try_shape(ct: glance.CustomType) -> Option(ScalarTypeDefinition) {
  case ct.variants {
    [] -> None
    variants ->
      case
        list.all(variants, fn(v) {
          case v.fields {
            [] -> True
            _ -> False
          }
        })
      {
        True ->
          Some(ScalarTypeDefinition(
            ct.name,
            list.map(variants, fn(v) { v.name }),
          ))
        False -> None
      }
  }
}
