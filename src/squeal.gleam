import argv
import generator/emit
import gleam/io
import glint

fn generate_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Read src/<MODULE>.gleam and write generated SQLite access layer under src/<type>_db/.",
  )
  use <- glint.unnamed_args(glint.EqArgs(1))
  use _named, args, _flags <- glint.command()
  let assert [module_name] = args
  case emit.run_generate(module_name) {
    Ok(layer) -> io.println("Wrote src/" <> layer <> "/")
    Error(msg) -> {
      io.print_error(msg <> "\n")
      panic as "squeal: generation failed"
    }
  }
}

pub fn main() -> Nil {
  glint.new()
  |> glint.with_name("squeal")
  |> glint.as_module()
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: [], do: generate_command())
  |> glint.run(argv.load().arguments)
}
