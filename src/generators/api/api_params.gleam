import generators/api/api_decoders as dec
import generators/api/api_sql
import generators/sql_types
import gleam/list
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type FieldDefinition, type IdentityVariantDefinition,
}

pub fn conn_param() -> gparam.Parameter(gtypes.Dynamic) {
  gparam.new("conn", gtypes.raw("sqlight.Connection"))
  |> gparam.to_dynamic
}

/// Labelled parameter for generated public APIs (call sites use `name: value`). [conn_param] stays unlabelled.
pub fn consumer_param(
  name: String,
  type_: gtypes.GeneratedType(t),
) -> gparam.Parameter(gtypes.Dynamic) {
  gparam.new(name, type_)
  |> gparam.with_label(name)
  |> gparam.to_dynamic
}

/// Identity fields first (variant order), then remaining data columns — matches upsert command field order.
pub fn upsert_ordered_data_fields(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
) -> List(FieldDefinition) {
  let labels = dec.id_labels_list(variant)
  let extras =
    api_sql.entity_data_fields(entity)
    |> list.filter(fn(f) { !list.contains(labels, f.label) })
  list.append(variant.fields, extras)
}

pub fn identity_gparams(
  v: IdentityVariantDefinition,
) -> List(gparam.Parameter(gtypes.Dynamic)) {
  list.map(v.fields, fn(f) {
    consumer_param(
      f.label,
      gtypes.raw(sql_types.identity_upsert_param_type(f.type_)),
    )
  })
}
