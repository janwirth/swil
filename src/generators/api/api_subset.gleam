/// Helpers for `Subset` query shape codegen: naming, type inference, and gleamgen
/// chunks that emit the `QueryFooBarOutput` type + decoder into the `row` module.
///
/// This module has no dependencies on other `api_*` generators, so it can be
/// imported by both `api_decoders` and `api_query` without creating cycles.

import generators/gleamgen_emit
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleamgen/expression as gexpr
import gleamgen/function as gfun
import gleamgen/module as gmod
import gleamgen/types as gtypes
import gleamgen/types/custom as gcustom
import gleamgen/types/variant as gvariant
import schema_definition/schema_definition.{
  type Expr, type QuerySpecDefinition, AgeFn, Call, ExcludeIfMissingFn, Field,
  NoneOrBase, NullableFn, Param, ShapeField, Subset,
}

// ── Naming ───────────────────────────────────────────────────────────────────

/// `query_old_hippos_owner_emails` → `QueryOldHipposOwnerEmailsOutput`
pub fn output_type_name(spec_name: String) -> String {
  let base = case string.starts_with(spec_name, "query_") {
    True -> string.drop_start(spec_name, 6)
    False -> spec_name
  }
  "Query" <> snake_to_pascal(base) <> "Output"
}

/// `query_old_hippos_owner_emails` → `query_old_hippos_owner_emails_output_decoder`
pub fn output_decoder_fn_name(spec_name: String) -> String {
  spec_name <> "_output_decoder"
}

fn snake_to_pascal(s: String) -> String {
  s
  |> string.split("_")
  |> list.map(string.capitalise)
  |> string.join("")
}

// ── Type inference from DSL Expr ─────────────────────────────────────────────

/// Gleam type string for a shape field expression.
pub fn expr_gleam_type(expr: Expr) -> String {
  case expr {
    Call(AgeFn, _) -> "Int"
    Call(NullableFn, _) -> "option.Option(String)"
    Call(ExcludeIfMissingFn, [inner]) -> expr_gleam_type(inner)
    Call(ExcludeIfMissingFn, _) -> "String"
    Field(_) -> "String"
    Param(_) -> "String"
  }
}

/// `decode.*` decoder expression for a shape field expression.
pub fn expr_sql_decoder(expr: Expr) -> String {
  case expr {
    Call(AgeFn, _) -> "decode.int"
    Call(NullableFn, _) -> "decode.optional(decode.string)"
    Call(ExcludeIfMissingFn, [inner]) -> expr_sql_decoder(inner)
    Call(ExcludeIfMissingFn, _) -> "decode.string"
    Field(_) -> "decode.string"
    Param(_) -> "decode.string"
  }
}

// ── gleamgen module chunk emitter ────────────────────────────────────────────

fn alias_or_fallback(alias_opt: Option(String), i: Int) -> String {
  case alias_opt {
    Some(a) -> a
    None -> "field_" <> int.to_string(i)
  }
}

/// Fold the `QueryFooBarOutput` type + decoder for every `Subset` spec into
/// `module`, appending them after the existing entity row decoders.
pub fn fold_subset_output_into_module(
  specs: List(QuerySpecDefinition),
  module: gmod.Module,
) -> gmod.Module {
  list.fold(specs, module, fn(acc, spec) {
    case spec.query.shape {
      NoneOrBase -> acc
      Subset(selection) -> {
        let type_name = output_type_name(spec.name)
        let decoder_fn_name = output_decoder_fn_name(spec.name)

        // Build the variant arguments: [(Some("age"), Int), (Some("owner_email"), option.Option(String))]
        let variant_args =
          list.index_map(selection, fn(item, i) {
            let ShapeField(alias: alias_opt, expr: e) = item
            let label = alias_or_fallback(alias_opt, i)
            #(Some(label), gtypes.raw(expr_gleam_type(e)))
          })

        // CustomTypeBuilder with one variant (the single record constructor)
        let variant =
          gvariant.new(type_name)
          |> gvariant.with_arguments_dynamic(
            list.map(variant_args, fn(arg) {
              let #(label, t) = arg
              #(label, gtypes.to_dynamic(t))
            }),
          )
        let ct =
          gcustom.new_dynamic(Nil, [gvariant.to_dynamic(variant)], [])

        // Decoder body: use-chain + decode.success(TypeName(field:, ...))
        let uses =
          list.index_map(selection, fn(item, i) {
            let ShapeField(alias: alias_opt, expr: e) = item
            let label = alias_or_fallback(alias_opt, i)
            "use "
            <> label
            <> " <- decode.field("
            <> int.to_string(i)
            <> ", "
            <> expr_sql_decoder(e)
            <> ")"
          })
          |> string.join("\n  ")
        let constructor_args =
          list.index_map(selection, fn(item, i) {
            let ShapeField(alias: alias_opt, ..) = item
            alias_or_fallback(alias_opt, i) <> ":"
          })
          |> string.join(", ")
        let decoder_body =
          uses
          <> "\n  decode.success("
          <> type_name
          <> "("
          <> constructor_args
          <> "))"

        // Emit type, then decoder function — each prepends to `acc`
        let with_decoder =
          gmod.with_function(
            gleamgen_emit.pub_def(decoder_fn_name),
            gfun.new_raw(
              [],
              gtypes.raw("decode.Decoder(" <> type_name <> ")"),
              fn(_) { gexpr.raw(decoder_body) },
            )
              |> gfun.to_dynamic,
            fn(_) { acc },
          )
        gmod.with_custom_type_dynamic(
          gleamgen_emit.pub_def(type_name),
          ct,
          fn(_, _) { with_decoder },
        )
      }
    }
  })
}

/// Raw Gleam source appended to the rendered `row` module for each `Subset` spec.
pub fn subset_output_appendage(specs: List(QuerySpecDefinition)) -> String {
  list.fold(specs, "", fn(acc, spec) {
    case spec.query.shape {
      NoneOrBase -> acc
      Subset(selection) -> {
        let type_name = output_type_name(spec.name)
        let decoder_fn_name = output_decoder_fn_name(spec.name)
        let field_pairs =
          list.index_map(selection, fn(item, i) {
            let ShapeField(alias: alias_opt, expr: e) = item
            let label = alias_or_fallback(alias_opt, i)
            label <> ": " <> expr_gleam_type(e)
          })
        let fields_csv = string.join(field_pairs, ", ")
        let type_block =
          "\n\npub type "
          <> type_name
          <> " {\n  "
          <> type_name
          <> "("
          <> fields_csv
          <> ")\n}"
        let uses =
          list.index_map(selection, fn(item, i) {
            let ShapeField(alias: alias_opt, expr: e) = item
            let label = alias_or_fallback(alias_opt, i)
            "  use "
            <> label
            <> " <- decode.field("
            <> int.to_string(i)
            <> ", "
            <> expr_sql_decoder(e)
            <> ")"
          })
          |> string.join("\n")
        let ctor_args =
          list.index_map(selection, fn(item, i) {
            let ShapeField(alias: alias_opt, ..) = item
            alias_or_fallback(alias_opt, i) <> ":"
          })
          |> string.join(", ")
        let fn_block =
          "\n\npub fn "
          <> decoder_fn_name
          <> "() -> decode.Decoder("
          <> type_name
          <> ") {\n"
          <> uses
          <> "\n  decode.success("
          <> type_name
          <> "("
          <> ctor_args
          <> "))\n}"
        acc <> type_block <> fn_block
      }
    }
  })
}
