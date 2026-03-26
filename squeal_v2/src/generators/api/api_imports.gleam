import generators/api/schema_context
import gleam/string
import gleamgen/import_ as gimport
import gleamgen/module as gmod
import schema_definition/schema_definition.{type SchemaDefinition}

pub fn with_api_imports(
  migration_path: String,
  schema_path: String,
  def: SchemaDefinition,
  exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let mig_parts = string.split(migration_path, "/")
  let sch_parts = string.split(schema_path, "/")
  let after_result = fn() -> gmod.Module {
    case schema_context.schema_uses_calendar_date(def) {
      False -> {
        use _ <- gmod.with_import(
          gimport.new_predefined(["gleam", "time", "timestamp"]),
        )
        use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
        inner()
      }
      True -> {
        use _ <- gmod.with_import(gimport.new_predefined(["gleam", "int"]))
        use _ <- gmod.with_import(gimport.new_predefined(["gleam", "string"]))
        use _ <- gmod.with_import(
          gimport.new_with_exposing(
            ["gleam", "time", "calendar"],
            "type Date, Date as CalDate, month_from_int, month_to_int",
          ),
        )
        use _ <- gmod.with_import(
          gimport.new_predefined(["gleam", "time", "timestamp"]),
        )
        use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
        inner()
      }
    }
  }
  use _ <- gmod.with_import(gimport.new(mig_parts))
  use _ <- gmod.with_import(gimport.new_with_exposing(sch_parts, exposing))
  use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
  use _ <- gmod.with_import(
    gimport.new_predefined(["gleam", "dynamic", "decode"]),
  )
  use _ <- gmod.with_import(
    gimport.new_with_exposing(
      ["gleam", "option"],
      "type Option, None, Some",
    ),
  )
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "result"]))
  after_result()
}
