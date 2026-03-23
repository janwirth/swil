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
      "sqlight.nullable(sqlight.int, map("
      <> prefix
      <> "."
      <> label
      <> ", fn(b) { case b { True -> 1 False -> 0 } }))"
    "Option(String)" ->
      "sqlight.nullable(sqlight.text, " <> prefix <> "." <> label <> ")"
    _ ->
      "sqlight.nullable(sqlight.text, " <> prefix <> "." <> label <> ")"
  }
}

pub fn from_identity_string(binding: String) -> String {
  "sqlight.text(" <> binding <> ")"
}

/// INSERT values: identity fields use unwrapped params in the upsert variant but DB columns are optional.
pub fn from_identity_case_column(label: String, typ: glance.Type) -> String {
  case sql_types.rendered_type(typ) {
    "Option(String)" ->
      "sqlight.nullable(sqlight.text, option.Some(" <> label <> "))"
    "Option(Int)" ->
      "sqlight.nullable(sqlight.int, option.Some(" <> label <> "))"
    "Option(Bool)" ->
      "sqlight.nullable(sqlight.int, option.Some(case "
      <> label
      <> " { True -> 1 False -> 0 }))"
    "Option(Float)" ->
      "sqlight.nullable(sqlight.float, option.Some(" <> label <> "))"
    _ -> from_pattern_field(label, typ)
  }
}

/// WHERE bindings after upsert: plain SQL params from unwrapped identity variables.
pub fn from_identity_lookup_param(label: String, typ: glance.Type) -> String {
  case sql_types.rendered_type(typ) {
    "Option(String)" -> "sqlight.text(" <> label <> ")"
    "Option(Int)" -> "sqlight.int(" <> label <> ")"
    "Option(Bool)" ->
      "sqlight.int(case " <> label <> " { True -> 1 False -> 0 })"
    "Option(Float)" -> "sqlight.float(" <> label <> ")"
    _ -> from_pattern_field(label, typ)
  }
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
    "Option(Bool)" ->
      "sqlight.nullable(sqlight.int, option.map("
      <> label
      <> ", fn(b) { case b { True -> 1 False -> 0 } }))"
    "Option(String)" -> "sqlight.nullable(sqlight.text, " <> label <> ")"
    _ -> "sqlight.nullable(sqlight.text, " <> label <> ")"
  }
}
