import generators/api/api_decoders as dec
import generators/api/api_sql
import generators/sql_types
import gleam/list
import gleam/string
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

/// Identity fields first (variant order), then remaining data columns — matches `upsert_*` parameter order.
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
      consumer_param(f.label, gtypes.raw(dec.render_type(f.type_, ctx)))
    })
  list.append(id_ps, extras)
}

pub fn upsert_many_gparams(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  ctx: dec.TypeCtx,
  entity_type_name: String,
) -> List(gparam.Parameter(gtypes.Dynamic)) {
  let ordered = upsert_ordered_data_fields(entity, variant)
  let row_pair = dec.entity_row_tuple_type(ctx, entity_type_name)
  let upsert_row_arg_types =
    list.map(ordered, fn(f) { dec.render_type(f.type_, ctx) })
    |> string.join(", ")
  let upsert_row_fn =
    "fn("
    <> upsert_row_arg_types
    <> ") -> Result("
    <> row_pair
    <> ", sqlight.Error)"
  let each_fn =
    "fn(a, "
    <> upsert_row_fn
    <> ") -> Result("
    <> row_pair
    <> ", sqlight.Error)"
  list.flatten([
    [conn_param()],
    [
      consumer_param("items", gtypes.list(gtypes.generic("a"))),
      consumer_param("each", gtypes.raw(each_fn)),
    ],
  ])
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

/// Parameters for `update_<entity>_by_id`: row id, then every scalar column (same order as the table).
pub fn update_by_id_gparams(
  entity: EntityDefinition,
  ctx: dec.TypeCtx,
) -> List(gparam.Parameter(gtypes.Dynamic)) {
  let id_p = consumer_param("id", gtypes.int)
  let field_ps =
    api_sql.entity_data_fields(entity)
    |> list.map(fn(f) {
      consumer_param(f.label, gtypes.raw(dec.render_type(f.type_, ctx)))
    })
  [id_p, ..field_ps]
}
