import gleam/string

import gleamgen/module as gmod
import gleamgen/module/definition as gdef
import gleamgen/render as grender

pub fn render_module(m: gmod.Module) -> String {
  let s =
    gmod.render(m, grender.default_context())
    |> grender.to_string()
  case string.ends_with(s, "\n") {
    True -> s
    False -> s <> "\n"
  }
}

pub fn pub_def(name: String) -> gdef.Definition {
  gdef.new(name)
  |> gdef.with_publicity(True)
}
