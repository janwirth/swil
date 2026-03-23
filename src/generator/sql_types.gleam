import glance
import gleam/list
import gleam/option.{None}
import gleam/string
import gleamgen/render as gleamgen_render
import gleamgen/types as gleamgen_types

pub fn to_generated_type(type_: glance.Type) -> gleamgen_types.GeneratedType(
  gleamgen_types.Unchecked,
) {
  case type_ {
    glance.NamedType(_, "String", None, []) ->
      gleamgen_types.string |> gleamgen_types.to_unchecked
    glance.NamedType(_, "Int", None, []) ->
      gleamgen_types.int |> gleamgen_types.to_unchecked
    glance.NamedType(_, "Float", None, []) ->
      gleamgen_types.float |> gleamgen_types.to_unchecked
    glance.NamedType(_, "Bool", None, []) ->
      gleamgen_types.bool |> gleamgen_types.to_unchecked
    glance.NamedType(_, "Nil", None, []) ->
      gleamgen_types.nil |> gleamgen_types.to_unchecked
    glance.NamedType(_, name, module, params) ->
      gleamgen_types.custom_type(module, name, list.map(params, to_generated_type))
    glance.TupleType(_, elements) ->
      gleamgen_types.custom_type(None, "Tuple", list.map(elements, to_generated_type))
    glance.FunctionType(_, _, _) -> gleamgen_types.unchecked()
    glance.VariableType(_, name) -> gleamgen_types.unchecked_ident(name)
    glance.HoleType(_, _) -> gleamgen_types.unchecked()
  }
}

pub fn rendered_type(type_: glance.Type) -> String {
  case to_generated_type(type_) |> gleamgen_types.render_type {
    Ok(rendered) -> gleamgen_render.to_string(rendered)
    Error(_) -> "Unknown"
  }
}

pub fn sql_type(type_: glance.Type) -> String {
  case rendered_type(type_) {
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

pub fn filter_is_string_column(type_: glance.Type) -> Bool {
  case rendered_type(type_) {
    "String" -> True
    rendered ->
      string.starts_with(rendered, "Option(String)")
  }
}
