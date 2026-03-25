import glance
import glance_armstrong
import gleam/option.{type Option, None, Some}

/// Render with [`format_parse_error`](#format_parse_error) / [`schema_diagnostics`](schema_diagnostics.html).
pub type ParseError {
  GlanceError(glance.Error)
  UnsupportedSchema(span: Option(glance.Span), message: String)
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
