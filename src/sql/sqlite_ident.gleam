import gleam/string

/// Double-quote a SQLite identifier (`"col"`), escaping embedded `"` as `""`.
/// Use for column and table names from user schemas so reserved words (e.g. `order`) parse.
pub fn quote(label: String) -> String {
  let escaped = string.replace(label, "\"", "\"\"")
  "\"" <> escaped <> "\""
}
