import generator/emit
import gleam/io

/// Regenerates `cat_db` and `dog_db` from `cat_schema` / `dog_schema`.
/// Run before `gleam test` so ORM integration tests compile against current codegen
/// (`bun run test` does both steps).
pub fn main() -> Nil {
  case emit.run_generate("cat_schema") {
    Ok(layer) -> io.println("Wrote src/" <> layer <> "/")
    Error(msg) -> panic as { "regenerate_orm_layers: " <> msg }
  }
  case emit.run_generate("dog_schema") {
    Ok(layer) -> io.println("Wrote src/" <> layer <> "/")
    Error(msg) -> panic as { "regenerate_orm_layers: " <> msg }
  }
}
