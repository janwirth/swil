import glance
import gleam/list
import gleam/option.{None}
import gleam/string
import gleamgen/render as gleamgen_render
import gleamgen/types as gleamgen_types

fn to_generated_type(
  type_: glance.Type,
) -> gleamgen_types.GeneratedType(gleamgen_types.Dynamic) {
  case type_ {
    glance.NamedType(_, "String", None, []) ->
      gleamgen_types.string |> gleamgen_types.to_dynamic
    glance.NamedType(_, "Int", None, []) ->
      gleamgen_types.int |> gleamgen_types.to_dynamic
    glance.NamedType(_, "Float", None, []) ->
      gleamgen_types.float |> gleamgen_types.to_dynamic
    glance.NamedType(_, "Bool", None, []) ->
      gleamgen_types.bool |> gleamgen_types.to_dynamic
    glance.NamedType(_, "Date", None, []) ->
      gleamgen_types.raw("calendar.Date") |> gleamgen_types.to_dynamic
    glance.NamedType(_, "Timestamp", _, []) ->
      gleamgen_types.raw("timestamp.Timestamp") |> gleamgen_types.to_dynamic
    glance.NamedType(_, "Nil", None, []) ->
      gleamgen_types.nil |> gleamgen_types.to_dynamic
    glance.NamedType(_, name, module, params) ->
      gleamgen_types.custom_type(
        module,
        name,
        list.map(params, to_generated_type),
      )
    glance.TupleType(_, elements) ->
      gleamgen_types.custom_type(
        None,
        "Tuple",
        list.map(elements, to_generated_type),
      )
    glance.FunctionType(_, _, _) -> gleamgen_types.dynamic()
    glance.VariableType(_, name) -> gleamgen_types.raw(name)
    glance.HoleType(_, _) -> gleamgen_types.dynamic()
  }
}

pub fn rendered_type(type_: glance.Type) -> String {
  case to_generated_type(type_) |> gleamgen_types.render_type {
    Ok(rendered) -> gleamgen_render.to_string(rendered)
    Error(_) -> "Unknown"
  }
}

/// Parameter type for `*_with_*` helpers: schema `Option(t)` identity fields use plain `t`.
pub fn identity_upsert_param_type(type_: glance.Type) -> String {
  let r = rendered_type(type_)
  case string.starts_with(r, "Option(") && string.ends_with(r, ")") {
    True -> string.drop_end(string.drop_start(r, 7), 1)
    False -> r
  }
}

fn normalized_rendered(type_: glance.Type) -> String {
  let r = rendered_type(type_)
  case string.starts_with(r, "option.") {
    True -> string.drop_start(r, 7)
    False -> r
  }
}

/// True when the column is stored as SQLite `integer` (Unix seconds for `Timestamp` / `Option(Timestamp)`).
pub fn type_stored_as_unix_int(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Timestamp", _, []) -> True
    glance.NamedType(_, "Option", _, [inner]) -> type_stored_as_unix_int(inner)
    _ -> False
  }
}

pub fn sql_type(type_: glance.Type) -> String {
  case type_stored_as_unix_int(type_) {
    True -> "int"
    False ->
      case normalized_rendered(type_) {
        "Int" -> "int"
        "Float" -> "real"
        "Bool" -> "int"
        "String" -> "text"
        rendered ->
          case string.starts_with(rendered, "Option(") {
            False -> "text"
            True ->
              case rendered {
                "Option(Int)" -> "int"
                "Option(Float)" -> "real"
                "Option(Bool)" -> "int"
                _ -> "text"
              }
          }
      }
  }
}

pub fn filter_is_string_column(type_: glance.Type) -> Bool {
  case rendered_type(type_) {
    "String" -> True
    rendered -> string.starts_with(rendered, "Option(String)")
  }
}

/// Gleam expression for a `gleam/dynamic/decode` decoder matching this field type.
pub fn decode_expression(type_: glance.Type) -> String {
  case rendered_type(type_) {
    "Int" -> "decode.int"
    "Float" -> "decode.float"
    "Bool" -> "decode.map(decode.int, fn(i) { i != 0 })"
    "String" -> "decode.string"
    "Nil" -> "decode.int"
    rendered ->
      case string.starts_with(rendered, "Option(") {
        False -> "decode.string"
        True ->
          case rendered {
            "Option(Int)" -> "decode.optional(decode.int)"
            "Option(Float)" -> "decode.optional(decode.float)"
            "Option(Bool)" ->
              "decode.optional(decode.map(decode.int, fn(i) { i != 0 }))"
            "Option(String)" -> "decode.optional(decode.string)"
            _ -> "decode.optional(decode.string)"
          }
      }
  }
}
