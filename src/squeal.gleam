import argv
import generator/full.{type GeneratedStructure, generate_full}
import generator/schema_context
import gleam/io
import gleam/result
import glint
import simplifile

fn write_text(path: String, content: String) -> Result(Nil, String) {
  simplifile.write(path, content)
  |> result.map_error(simplifile.describe_error)
}

fn emit_generated(root: String, gen: GeneratedStructure) -> Result(Nil, String) {
  use Nil <- result.try(write_text(root <> "/migrate.gleam", gen.migrate))
  use Nil <- result.try(write_text(root <> "/entry.gleam", gen.entry))
  use Nil <- result.try(write_text(root <> "/resource.gleam", gen.resource))
  use Nil <- result.try(write_text(root <> "/structure.gleam", gen.structure))
  use Nil <- result.try(write_text(root <> "/crud.gleam", gen.crud))
  let sub = gen.crud_submodules
  use Nil <- result.try(write_text(root <> "/crud/sort.gleam", sub.sort))
  use Nil <- result.try(write_text(root <> "/crud/filter.gleam", sub.filter))
  use Nil <- result.try(write_text(root <> "/crud/delete.gleam", sub.delete))
  use Nil <- result.try(write_text(root <> "/crud/read.gleam", sub.read))
  use Nil <- result.try(write_text(root <> "/crud/update.gleam", sub.update))
  use Nil <- result.try(write_text(root <> "/crud/upsert.gleam", sub.upsert))
  Ok(Nil)
}

fn run_generate(module_name: String) -> Result(String, String) {
  let path = "src/" <> module_name <> ".gleam"
  use src <- result.try(
    simplifile.read(path)
    |> result.map_error(simplifile.describe_error),
  )
  use ctx <- result.try(
    schema_context.parse(src, module_name)
    |> result.replace_error(
      "Could not parse schema module. Check SQLITE_LAYER_GENERATION → <layer>/..., first custom type + variant, identities/0 returning identity.Identity / Identity2 / Identity3 calls with field references, and optional import <layer>/entry as <name> for the table accessor (defaults to <type>s).",
    ),
  )
  let gen = generate_full(src, module_name)
  let root = "src/" <> ctx.layer
  use Nil <- result.try(
    simplifile.create_directory_all(root <> "/crud")
    |> result.map_error(simplifile.describe_error),
  )
  use Nil <- result.try(emit_generated(root, gen))
  Ok(ctx.layer)
}

fn generate_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Read src/<MODULE>.gleam and write generated SQLite access layer under src/<layer>/ (layer name comes from the SQLITE_LAYER_GENERATION comment).",
  )
  use <- glint.unnamed_args(glint.EqArgs(1))
  use _named, args, _flags <- glint.command()
  let assert [module_name] = args
  case run_generate(module_name) {
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
