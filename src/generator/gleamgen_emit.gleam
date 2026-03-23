import gleamgen/module as gmod
import gleamgen/render as grender

pub fn render_module(m: gmod.Module) -> String {
  gmod.render(m, grender.default_context())
  |> grender.to_string()
}

pub fn pub_def(name: String) -> gmod.DefinitionDetails {
  gmod.DefinitionDetails(name:, is_public: True, attributes: [])
}
