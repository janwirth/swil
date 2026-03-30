import glance
import glance_armstrong
import gleam/option.{type Option, None, Some}

/// Render with [`format_parse_error`](#format_parse_error) / [`schema_diagnostics`](schema_diagnostics.html).
pub type ParseError {
  GlanceError(glance.Error)
  UnsupportedSchema(span: Option(glance.Span), message: String)
}

/// Appended to errors about disallowed public [`glance.Function`](glance.Function) names.
pub fn hint_public_function_prefixes() -> String {
  "Hint: public functions in a skwil schema module must use prefix `query_` (query pipeline spec) or `predicate_` (BooleanFilter helper)."
}

/// Appended when a public custom type is neither a recognised suffix bucket nor a valid entity.
pub fn hint_public_type_suffixes_or_entity() -> String {
  "Hint: public types must end with `Scalar`, `Identities`, `Relationships`, or `Attributes`, or be a valid entity (one record variant named like the type with a labelled `identities: *Identities` field)."
}

/// Turn a [`ParseError`](#ParseError) into text using [`schema_diagnostics`](schema_diagnostics.html) (line + caret layout).
pub fn format_parse_error(source: String, error: ParseError) -> String {
  case error {
    GlanceError(e) -> glance_armstrong.format_glance_parse_error(source, e)
    UnsupportedSchema(None, message) ->
      glance_armstrong.format_diagnostic_without_span(message)
    UnsupportedSchema(Some(span), message) ->
      glance_armstrong.format_source_diagnostic(source, span, message)
  }
}
