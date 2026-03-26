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
      False ->
        gmod.with_import(
          gimport.new_predefined(["gleam", "time", "timestamp"]),
          fn(_) {
            gmod.with_import(gimport.new_predefined(["sqlight"]), fn(_) {
              inner()
            })
          },
        )
      True ->
        gmod.with_import(gimport.new_predefined(["gleam", "int"]), fn(_) {
          gmod.with_import(gimport.new_predefined(["gleam", "string"]), fn(_) {
            gmod.with_import(
              gimport.new_with_exposing(
                ["gleam", "time", "calendar"],
                "type Date, Date as CalDate, month_from_int, month_to_int",
              ),
              fn(_) {
                gmod.with_import(
                  gimport.new_predefined(["gleam", "time", "timestamp"]),
                  fn(_) {
                    gmod.with_import(gimport.new_predefined(["sqlight"]), fn(_) {
                      inner()
                    })
                  },
                )
              },
            )
          })
        })
    }
  }
  gmod.with_import(gimport.new(mig_parts), fn(_) {
    gmod.with_import(gimport.new_with_exposing(sch_parts, exposing), fn(_) {
      gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"), fn(_) {
        gmod.with_import(
          gimport.new_predefined(["gleam", "dynamic", "decode"]),
          fn(_) {
            gmod.with_import(
              gimport.new_with_exposing(
                ["gleam", "option"],
                "type Option, None, Some",
              ),
              fn(_) {
                gmod.with_import(
                  gimport.new_predefined(["gleam", "result"]),
                  fn(_) { after_result() },
                )
              },
            )
          },
        )
      })
    })
  })
}
