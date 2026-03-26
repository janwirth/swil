import glance
import gleam/list

/// Type name ends with `Scalar`: no `identities` required. Variants may be payload-free (enum-like)
/// or carry fields (e.g. a single record variant named like the type).
pub type ScalarTypeDefinition {
  ScalarTypeDefinition(
    type_name: String,
    variant_names: List(String),
    /// `True` when every variant has no fields (stored as variant label strings in SQL text columns).
    enum_only: Bool,
  )
}

pub fn from_custom_type(ct: glance.CustomType) -> ScalarTypeDefinition {
  let enum_only =
    list.all(ct.variants, fn(v) { list.is_empty(v.fields) })
  ScalarTypeDefinition(
    ct.name,
    list.map(ct.variants, fn(v) { v.name }),
    enum_only,
  )
}
