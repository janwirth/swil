import glance
import gleam/list

/// Type name ends with `Scalar`: no `identities` required. Variants may be payload-free (enum-like)
/// or carry fields (e.g. a single record variant named like the type).
pub type ScalarTypeDefinition {
  ScalarTypeDefinition(type_name: String, variant_names: List(String))
}

pub fn from_custom_type(ct: glance.CustomType) -> ScalarTypeDefinition {
  ScalarTypeDefinition(ct.name, list.map(ct.variants, fn(v) { v.name }))
}
