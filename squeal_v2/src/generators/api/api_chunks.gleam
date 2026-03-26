import generators/api/api_crud_bodies as crud_bodies
import generators/api/api_decoders as dec
import generators/api/api_params
import generators/api/api_update_delete as ud
import generators/api/schema_context
import generators/gleamgen_emit
import gleam/list
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type IdentityVariantDefinition, type SchemaDefinition,
}

pub fn optional_opt_for_db_fn_chunks(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
) {
  let opt_int_chunk = #(
    gdef.new("opt_int_for_db") |> gdef.with_publicity(False),
    gfun.new_raw(
      [gparam.new("o", gtypes.raw("Option(Int)")) |> gparam.to_dynamic],
      gtypes.int,
      fn(_) { gexpr.raw("case o {\n    Some(i) -> i\n    None -> 0\n  }") },
    )
      |> gfun.to_dynamic,
  )
  let opt_float_chunk = #(
    gdef.new("opt_float_for_db") |> gdef.with_publicity(False),
    gfun.new_raw(
      [gparam.new("o", gtypes.raw("Option(Float)")) |> gparam.to_dynamic],
      gtypes.float,
      fn(_) { gexpr.raw("case o {\n    Some(f) -> f\n    None -> 0.0\n  }") },
    )
      |> gfun.to_dynamic,
  )
  let opt_text_chunk = #(
    gdef.new("opt_text_for_db") |> gdef.with_publicity(False),
    gfun.new_raw(
      [gparam.new("o", gtypes.raw("Option(String)")) |> gparam.to_dynamic],
      gtypes.string,
      fn(_) { gexpr.raw("case o {\n    Some(s) -> s\n    None -> \"\"\n  }") },
    )
      |> gfun.to_dynamic,
  )
  list.flatten([
    case schema_context.entity_needs_opt_int_for_db(entity, variant) {
      True -> [opt_int_chunk]
      False -> []
    },
    case schema_context.entity_needs_opt_float_for_db(entity, variant) {
      True -> [opt_float_chunk]
      False -> []
    },
    case schema_context.entity_needs_opt_text_for_db(entity, variant) {
      True -> [opt_text_chunk]
      False -> []
    },
  ])
}

fn scalar_enum_from_db_raw(variants: List(String)) -> String {
  let arms =
    list.map(variants, fn(v) {
      "    \"" <> v <> "\" -> Some(" <> v <> ")"
    })
    |> string.join("\n")
  "case s {\n    \"\" -> None\n" <> arms <> "\n    _ -> None\n  }"
}

fn scalar_enum_to_db_raw(variants: List(String)) -> String {
  let some_arms =
    list.map(variants, fn(v) {
      "    Some(" <> v <> ") -> \"" <> v <> "\""
    })
    |> string.join("\n")
  "case o {\n    None -> \"\"\n" <> some_arms <> "\n  }"
}

pub fn scalar_enum_db_fn_chunks(def: SchemaDefinition, entity: EntityDefinition) {
  schema_context.entity_used_enum_scalars(def, entity)
  |> list.flat_map(fn(scalar) {
    let base = dec.scalar_type_snake_case(scalar.type_name)
    let from_fn = base <> "_from_db_string"
    let to_fn = base <> "_to_db_string"
    let from_body = scalar_enum_from_db_raw(scalar.variant_names)
    let to_body = scalar_enum_to_db_raw(scalar.variant_names)
    [
      #(
        gleamgen_emit.pub_def(from_fn),
        gfun.new_raw(
          [gparam.new("s", gtypes.string) |> gparam.to_dynamic],
          gtypes.raw("Option(" <> scalar.type_name <> ")"),
          fn(_) { gexpr.raw(from_body) },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gleamgen_emit.pub_def(to_fn),
        gfun.new_raw(
          [
            gparam.new("o", gtypes.raw("Option(" <> scalar.type_name <> ")"))
            |> gparam.to_dynamic,
          ],
          gtypes.string,
          fn(_) { gexpr.raw(to_body) },
        )
          |> gfun.to_dynamic,
      ),
    ]
  })
}

pub fn calendar_date_fn_chunks(path: String, def: SchemaDefinition) {
  let date_panic = schema_context.api_date_panic_label(path)
  case schema_context.schema_uses_calendar_date(def) {
    True -> [
      #(
        gdef.new("date_from_db_string") |> gdef.with_publicity(False),
        gfun.new_raw(
          [gparam.new("s", gtypes.string) |> gparam.to_dynamic],
          gtypes.raw("Date"),
          fn(_) {
            gexpr.raw(
              "case string.split(s, \"-\") {\n    [ys, ms, ds] -> {\n      let assert Ok(y) = int.parse(ys)\n      let assert Ok(mi) = int.parse(ms)\n      let assert Ok(d) = int.parse(ds)\n      let assert Ok(month) = month_from_int(mi)\n      CalDate(y, month, d)\n    }\n    _ -> panic as \""
              <> date_panic
              <> "\"\n  }",
            )
          },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gdef.new("date_to_db_string") |> gdef.with_publicity(False),
        gfun.new_raw(
          [gparam.new("d", gtypes.raw("Date")) |> gparam.to_dynamic],
          gtypes.string,
          fn(_) {
            gexpr.raw(
              "let CalDate(year:, month:, day:) = d\n  int.to_string(year)\n  <> \"-\"\n  <> pad2(month_to_int(month))\n  <> \"-\"\n  <> pad2(day)",
            )
          },
        )
          |> gfun.to_dynamic,
      ),
      #(
        gdef.new("pad2") |> gdef.with_publicity(False),
        gfun.new_raw(
          [gparam.new("n", gtypes.int) |> gparam.to_dynamic],
          gtypes.string,
          fn(_) {
            gexpr.raw(
              "let s = int.to_string(n)\n  case string.length(s) {\n    1 -> \"0\" <> s\n    _ -> s\n  }",
            )
          },
        )
          |> gfun.to_dynamic,
      ),
    ]
    False -> []
  }
}

pub fn crud_public_fn_chunks(
  entity: EntityDefinition,
  variant: IdentityVariantDefinition,
  entity_snake: String,
  id_snake: String,
  upsert_params: List(gparam.Parameter(gtypes.Dynamic)),
  get_params: List(gparam.Parameter(gtypes.Dynamic)),
  row_t,
  sql_err,
  enum_scalar_names: List(String),
) {
  [
    #(
      gleamgen_emit.pub_def("last_100_edited_" <> entity_snake)
        |> gdef.with_text_before(
          "/// List up to 100 recently edited " <> entity_snake <> " rows.\n",
        ),
      gfun.new_raw(
        [api_params.conn_param()],
        gtypes.result(gtypes.list(row_t), sql_err),
        fn(_) { gexpr.raw(crud_bodies.last_fn_body(entity_snake)) },
      )
        |> gfun.to_dynamic,
    ),
    ud.delete_fn_chunk(entity_snake, id_snake, variant, get_params, sql_err),
    ud.update_fn_chunk(
      entity,
      variant,
      entity_snake,
      id_snake,
      upsert_params,
      row_t,
      sql_err,
      enum_scalar_names,
    ),
    #(
      gleamgen_emit.pub_def("get_" <> entity_snake <> "_by_" <> id_snake)
        |> gdef.with_text_before(
          "/// Get a "
          <> entity_snake
          <> " by the `"
          <> variant.variant_name
          <> "` identity.\n",
        ),
      gfun.new_raw(
        get_params,
        gtypes.result(
          gtypes.raw(
            "Option(" <> dec.entity_row_tuple_type(entity.type_name) <> ")",
          ),
          sql_err,
        ),
        fn(_) {
          gexpr.raw(crud_bodies.get_fn_body(variant, entity_snake, id_snake))
        },
      )
        |> gfun.to_dynamic,
    ),
    #(
      gleamgen_emit.pub_def("upsert_" <> entity_snake <> "_by_" <> id_snake)
        |> gdef.with_text_before(
          "/// Upsert a "
          <> entity_snake
          <> " by the `"
          <> variant.variant_name
          <> "` identity.\n",
        ),
      gfun.new_raw(upsert_params, gtypes.result(row_t, sql_err), fn(_) {
        gexpr.raw(ud.upsert_fn_body(
          entity,
          variant,
          entity_snake,
          id_snake,
          "upsert",
          enum_scalar_names,
        ))
      })
        |> gfun.to_dynamic,
    ),
    #(
      gleamgen_emit.pub_def("migrate"),
      gfun.new_raw(
        [api_params.conn_param()],
        gtypes.result(gtypes.nil, sql_err),
        fn(_) { gexpr.raw("migration.migration(conn)") },
      )
        |> gfun.to_dynamic,
    ),
    #(
      gdef.new("not_found_error") |> gdef.with_publicity(False),
      gfun.new_raw(
        [gparam.new("op", gtypes.string) |> gparam.to_dynamic],
        gtypes.raw("sqlight.Error"),
        fn(_) {
          gexpr.raw(
            "sqlight.SqlightError(sqlight.GenericError, \""
            <> entity_snake
            <> " not found: \" <> op, -1)",
          )
        },
      )
        |> gfun.to_dynamic,
    ),
  ]
}

pub fn unix_seconds_now_fn_chunk() {
  #(
    gdef.new("unix_seconds_now") |> gdef.with_publicity(False),
    gfun.new_raw([], gtypes.int, fn(_) {
      gexpr.raw(
        "let #(s, _) =\n    timestamp.system_time()\n    |> timestamp.to_unix_seconds_and_nanoseconds\n  s",
      )
    })
      |> gfun.to_dynamic,
  )
}
