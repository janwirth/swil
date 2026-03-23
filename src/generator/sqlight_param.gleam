import glance

import generator/sql_types

pub fn from_record_field(prefix: String, label: String, typ: glance.Type) -> String {
  let r = sql_types.rendered_type(typ)
  case r {
    "Int" -> "sqlight.int(" <> prefix <> "." <> label <> ")"
    "Float" -> "sqlight.float(" <> prefix <> "." <> label <> ")"
    "Bool" -> "sqlight.int(" <> prefix <> "." <> label <> ")"
    "String" -> "sqlight.text(" <> prefix <> "." <> label <> ")"
    "Option(Int)" ->
      "sqlight.nullable(sqlight.int, " <> prefix <> "." <> label <> ")"
    "Option(Float)" ->
      "sqlight.nullable(sqlight.float, " <> prefix <> "." <> label <> ")"
    "Option(Bool)" ->
      "sqlight.nullable(sqlight.int, " <> prefix <> "." <> label <> ")"
    "Option(String)" ->
      "sqlight.nullable(sqlight.text, " <> prefix <> "." <> label <> ")"
    _ ->
      "sqlight.nullable(sqlight.text, " <> prefix <> "." <> label <> ")"
  }
}

pub fn from_identity_string(binding: String) -> String {
  "sqlight.text(" <> binding <> ")"
}

/// Bindings inside a `case` branch where row fields are in scope by label (e.g. `age` not `cat.age`).
pub fn from_pattern_field(label: String, typ: glance.Type) -> String {
  let r = sql_types.rendered_type(typ)
  case r {
    "Int" -> "sqlight.int(" <> label <> ")"
    "Float" -> "sqlight.float(" <> label <> ")"
    "Bool" -> "sqlight.int(" <> label <> ")"
    "String" -> "sqlight.text(" <> label <> ")"
    "Option(Int)" -> "sqlight.nullable(sqlight.int, " <> label <> ")"
    "Option(Float)" -> "sqlight.nullable(sqlight.float, " <> label <> ")"
    "Option(Bool)" -> "sqlight.nullable(sqlight.int, " <> label <> ")"
    "Option(String)" -> "sqlight.nullable(sqlight.text, " <> label <> ")"
    _ -> "sqlight.nullable(sqlight.text, " <> label <> ")"
  }
}
