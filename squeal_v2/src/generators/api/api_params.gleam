import generators/api/api_decoders as dec
import generators/api/api_sql
import generators/sql_types
import gleam/list
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type IdentityVariantDefinition,
}

pub fn conn_param() -> gparam.Parameter(gtypes.Dynamic) {
  gparam.new("conn", gtypes.raw("sqlight.Connection"))
  |> gparam.to_dynamic
}

pub fn upsert_gparams(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  ctx: dec.TypeCtx,
) -> List(gparam.Parameter(gtypes.Dynamic)) {
  let id_ps = identity_gparams(variant)
  let labels = dec.id_labels_list(variant)
  let extras =
    api_sql.entity_data_fields(entity)
    |> list.filter(fn(f) { !list.contains(labels, f.label) })
    |> list.map(fn(f) {
      gparam.new(f.label, gtypes.raw(dec.render_type(f.type_, ctx)))
      |> gparam.to_dynamic
    })
  list.append(id_ps, extras)
}

pub fn identity_gparams(
  v: IdentityVariantDefinition,
) -> List(gparam.Parameter(gtypes.Dynamic)) {
  list.map(v.fields, fn(f) {
    gparam.new(
      f.label,
      gtypes.raw(sql_types.identity_upsert_param_type(f.type_)),
    )
    |> gparam.to_dynamic
  })
}
