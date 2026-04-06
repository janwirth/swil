import generators/api/api_decoders as dec
import generators/api/api_params
import generators/api/schema_context
import generators/gleamgen_emit
import glance
import gleam/list
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module/definition as gdef
import gleamgen/parameter as gparam
import gleamgen/types as gtypes
import schema_definition/schema_definition.{
  type EntityDefinition, type ScalarTypeDefinition, type VariantWithFields,
}

fn scalar_enum_from_db_expr(
  _s: gexpr.Expression(String),
  variants: List(String),
  schema_alias: String,
) -> gexpr.Expression(a) {
  let c =
    gexpr.raw(
      "case s {\n    \"\" -> option.None\n"
      <> string.join(
        list.map(variants, fn(v) {
          "    \""
          <> v
          <> "\" -> option.Some("
          <> schema_alias
          <> "."
          <> v
          <> ")"
        }),
        "\n",
      )
      <> "\n    _ -> option.None\n  }",
    )
  c
}

fn scalar_enum_to_db_expr(
  _o: gexpr.Expression(gtypes.Dynamic),
  variants: List(String),
  schema_alias: String,
) -> gexpr.Expression(String) {
  let branches =
    string.join(
      list.map(variants, fn(v) {
        "    option.Some(" <> schema_alias <> "." <> v <> ") -> \"" <> v <> "\""
      }),
      "\n",
    )
  gexpr.raw("case o {\n    option.None -> \"\"\n" <> branches <> "\n  }")
}

fn field_encoder_expr(v: String, t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "String", _, []) -> "json.string(" <> v <> ")"
    glance.NamedType(_, "Int", _, []) -> "json.int(" <> v <> ")"
    glance.NamedType(_, "Float", _, []) -> "json.float(" <> v <> ")"
    glance.NamedType(_, "Bool", _, []) -> "json.bool(" <> v <> ")"
    glance.NamedType(_, "Option", _, [inner]) ->
      "json.nullable("
      <> v
      <> ", of: fn(x) { "
      <> field_encoder_expr("x", inner)
      <> " })"
    glance.NamedType(_, "List", _, [inner]) ->
      "json.array("
      <> v
      <> ", of: fn(x) { "
      <> field_encoder_expr("x", inner)
      <> " })"
    _ -> "json.string(\"unsupported\")"
  }
}

fn field_decoder_expr(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "String", _, []) -> "decode.string"
    glance.NamedType(_, "Int", _, []) -> "decode.int"
    glance.NamedType(_, "Float", _, []) -> "decode.float"
    glance.NamedType(_, "Bool", _, []) -> "decode.bool"
    glance.NamedType(_, "Option", _, [inner]) ->
      "decode.optional(" <> field_decoder_expr(inner) <> ")"
    glance.NamedType(_, "List", _, [inner]) ->
      "decode.list(of: " <> field_decoder_expr(inner) <> ")"
    _ -> "decode.string"
  }
}

fn placeholder_expr(t: glance.Type) -> String {
  case t {
    glance.NamedType(_, "String", _, []) -> "\"\""
    glance.NamedType(_, "Int", _, []) -> "0"
    glance.NamedType(_, "Float", _, []) -> "0.0"
    glance.NamedType(_, "Bool", _, []) -> "False"
    glance.NamedType(_, "Option", _, _) -> "option.None"
    glance.NamedType(_, "List", _, _) -> "[]"
    _ -> "option.None"
  }
}

fn scalar_variant_placeholder(
  v: VariantWithFields,
  schema_alias: String,
) -> String {
  case v.fields {
    [] -> schema_alias <> "." <> v.variant_name
    fields ->
      schema_alias
      <> "."
      <> v.variant_name
      <> "("
      <> string.join(
        list.map(fields, fn(f) { f.label <> ": " <> placeholder_expr(f.type_) }),
        ", ",
      )
      <> ")"
  }
}

fn non_enum_scalar_decoder_fn_body(
  scalar: ScalarTypeDefinition,
  schema_alias: String,
) -> String {
  let assert [first, ..] = scalar.variants
  let branches =
    scalar.variants
    |> list.map(fn(v) {
      case v.fields {
        [] ->
          "    \""
          <> v.variant_name
          <> "\" -> decode.success("
          <> schema_alias
          <> "."
          <> v.variant_name
          <> ")"
        fields -> {
          let uses =
            fields
            |> list.map(fn(f) {
              "      use "
              <> f.label
              <> " <- decode.field(\""
              <> f.label
              <> "\", "
              <> field_decoder_expr(f.type_)
              <> ")"
            })
            |> string.join("\n")
          let construct =
            schema_alias
            <> "."
            <> v.variant_name
            <> "("
            <> string.join(list.map(fields, fn(f) { f.label <> ":" }), ", ")
            <> ")"
          "    \""
          <> v.variant_name
          <> "\" -> {\n"
          <> uses
          <> "\n      decode.success("
          <> construct
          <> ")\n    }"
        }
      }
    })
    |> string.join("\n")
  "{\n  use tag <- decode.field(\"tag\", decode.string)\n  case tag {\n"
  <> branches
  <> "\n    _ -> decode.failure("
  <> scalar_variant_placeholder(first, schema_alias)
  <> ", expected: \""
  <> scalar.type_name
  <> "\")\n  }\n}"
}

fn non_enum_scalar_to_db_fn_body(
  scalar: ScalarTypeDefinition,
  schema_alias: String,
) -> String {
  let branches =
    scalar.variants
    |> list.map(fn(v) {
      case v.fields {
        [] ->
          "    option.Some("
          <> schema_alias
          <> "."
          <> v.variant_name
          <> ") -> json.to_string(json.object([#(\"tag\", json.string(\""
          <> v.variant_name
          <> "\"))]))"
        fields -> {
          let kvs =
            fields
            |> list.map(fn(f) {
              "#(\""
              <> f.label
              <> "\", "
              <> field_encoder_expr(f.label, f.type_)
              <> ")"
            })
            |> string.join(", ")
          "    option.Some("
          <> schema_alias
          <> "."
          <> v.variant_name
          <> "("
          <> string.join(list.map(fields, fn(f) { f.label <> ":" }), ", ")
          <> ")) -> json.to_string(json.object([#(\"tag\", json.string(\""
          <> v.variant_name
          <> "\")), "
          <> kvs
          <> "]))"
        }
      }
    })
    |> string.join("\n")
  "case o {\n  option.None -> \"null\"\n" <> branches <> "\n}"
}

fn non_enum_scalar_from_db_fn_body(
  scalar: ScalarTypeDefinition,
  decoder_fn_name: String,
) -> String {
  "case json.parse(from: s, using: decode.optional("
  <> decoder_fn_name
  <> "())) {\n  Ok(v) -> Ok(v)\n  Error(_e) -> Error(\"Failed decoding "
  <> scalar.type_name
  <> " from JSON: \" <> s)\n}"
}

fn non_enum_scalar_fn_chunks(scalar: ScalarTypeDefinition, ctx: dec.TypeCtx) {
  let base = dec.scalar_type_snake_case(scalar.type_name)
  let decode_fn = base <> "_json_decoder"
  let from_fn = dec.scalar_from_db_fn_name(scalar.type_name)
  let to_fn = dec.scalar_to_db_fn_name(scalar.type_name)
  let q = ctx.schema_alias <> "." <> scalar.type_name
  let opt_scalar_t = gtypes.raw("option.Option(" <> q <> ")")
  [
    #(
      gdef.new(decode_fn) |> gdef.with_publicity(False),
      gfun.new_raw([], gtypes.raw("decode.Decoder(" <> q <> ")"), fn(_) {
        gexpr.raw(non_enum_scalar_decoder_fn_body(scalar, ctx.schema_alias))
      })
        |> gfun.to_dynamic,
    ),
    #(
      gleamgen_emit.pub_def(to_fn),
      gfun.new_raw(
        [api_params.consumer_param("o", opt_scalar_t)],
        gtypes.string,
        fn(_) {
          gexpr.raw(non_enum_scalar_to_db_fn_body(scalar, ctx.schema_alias))
        },
      )
        |> gfun.to_dynamic,
    ),
    #(
      gleamgen_emit.pub_def(from_fn),
      gfun.new_raw(
        [api_params.consumer_param("s", gtypes.string)],
        gtypes.raw("Result(option.Option(" <> q <> "), String)"),
        fn(_) { gexpr.raw(non_enum_scalar_from_db_fn_body(scalar, decode_fn)) },
      )
        |> gfun.to_dynamic,
    ),
  ]
}

fn enum_scalar_fn_chunks(scalar: ScalarTypeDefinition, ctx: dec.TypeCtx) {
  let from_fn = dec.scalar_from_db_fn_name(scalar.type_name)
  let to_fn = dec.scalar_to_db_fn_name(scalar.type_name)
  let q = ctx.schema_alias <> "." <> scalar.type_name
  let opt_scalar = gtypes.raw("option.Option(" <> q <> ")")
  [
    #(
      gleamgen_emit.pub_def(from_fn),
      gfun.new1(
        param1: gparam.new("s", gtypes.string) |> gparam.with_label("s"),
        returns: opt_scalar,
        handler: fn(s) {
          scalar_enum_from_db_expr(s, scalar.variant_names, ctx.schema_alias)
        },
      )
        |> gfun.to_dynamic,
    ),
    #(
      gleamgen_emit.pub_def(to_fn),
      gfun.new1(
        param1: gparam.new("o", opt_scalar) |> gparam.with_label("o"),
        returns: gtypes.string,
        handler: fn(o) {
          scalar_enum_to_db_expr(
            gexpr.to_dynamic(o),
            scalar.variant_names,
            ctx.schema_alias,
          )
        },
      )
        |> gfun.to_dynamic,
    ),
  ]
}

pub fn scalar_db_fn_chunks(def, entity: EntityDefinition, ctx: dec.TypeCtx) {
  let used_names = schema_context.entity_used_scalar_type_names(def, entity)
  def.scalars
  |> list.filter(fn(s) { list.contains(used_names, s.type_name) })
  |> list.flat_map(fn(s) {
    case s.enum_only {
      True -> enum_scalar_fn_chunks(s, ctx)
      False -> non_enum_scalar_fn_chunks(s, ctx)
    }
  })
}
