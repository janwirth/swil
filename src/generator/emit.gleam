import generator/full.{type GeneratedStructure, generate_full}
import generator/schema_context
import gleam/result
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

/// Writes `src/<layer>/` for the given schema module name (e.g. `"cat_schema"`).
pub fn run_generate(module_name: String) -> Result(String, String) {
  let path = "src/" <> module_name <> ".gleam"
  use src <- result.try(
    simplifile.read(path)
    |> result.map_error(simplifile.describe_error),
  )
  use ctx <- result.try(
    schema_context.parse(src, module_name)
    |> result.replace_error(
      "Could not parse schema module. Check first custom type + variant and identities/0 returning identity.Identity / Identity2 / Identity3 calls with field references.",
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
