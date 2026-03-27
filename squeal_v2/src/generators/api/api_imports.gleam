import generators/api/schema_context
import gleam/list
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
  use _ <- gmod.with_import(gimport.new_predefined(["api_help"]))
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

fn with_row_calendar_import(def: SchemaDefinition, inner: fn() -> gmod.Module) -> gmod.Module {
  case schema_context.schema_uses_calendar_date(def) {
    False -> inner()
    True -> {
      use _ <- gmod.with_import(
        gimport.new_with_exposing(["gleam", "time", "calendar"], "type Date"),
      )
      inner()
    }
  }
}

pub fn with_row_module_imports(
  db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  use _ <- gmod.with_import(gimport.new_predefined(["api_help"]))
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
  with_row_calendar_import(def, inner)
}

pub fn with_upsert_module_imports(
  db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  let db_parts = string.split(db_module_path, "/")
  let row_parts = list.append(db_parts, ["row"])
  use _ <- gmod.with_import(gimport.new_predefined(row_parts))
  use _ <- gmod.with_import(gimport.new_predefined(["api_help"]))
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
  use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
  case schema_context.schema_uses_calendar_date(def) {
    False -> {
      use _ <- gmod.with_import(
        gimport.new_predefined(["gleam", "time", "timestamp"]),
      )
      inner()
    }
    True -> {
      use _ <- gmod.with_import(
        gimport.new_with_exposing(["gleam", "time", "calendar"], "type Date"),
      )
      use _ <- gmod.with_import(
        gimport.new_predefined(["gleam", "time", "timestamp"]),
      )
      inner()
    }
  }
}

pub fn with_delete_module_imports(
  _db_module_path: String,
  _schema_path: String,
  def: SchemaDefinition,
  _exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  use _ <- gmod.with_import(gimport.new_predefined(["api_help"]))
  use _ <- gmod.with_import(
    gimport.new_predefined(["gleam", "dynamic", "decode"]),
  )
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "result"]))
  use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
  case schema_context.schema_uses_calendar_date(def) {
    False -> inner()
    True -> {
      use _ <- gmod.with_import(
        gimport.new_with_exposing(["gleam", "time", "calendar"], "type Date"),
      )
      inner()
    }
  }
}

pub fn with_query_module_imports(
  db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  let db_parts = string.split(db_module_path, "/")
  let row_parts = list.append(db_parts, ["row"])
  use _ <- gmod.with_import(gimport.new_predefined(row_parts))
  use _ <- gmod.with_import(gimport.new_with_exposing(sch_parts, exposing))
  use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "result"]))
  use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
  inner()
}

pub fn with_get_module_imports(
  db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  let db_parts = string.split(db_module_path, "/")
  let row_parts = list.append(db_parts, ["row"])
  use _ <- gmod.with_import(gimport.new_predefined(["api_help"]))
  use _ <- gmod.with_import(gimport.new_predefined(row_parts))
  use _ <- gmod.with_import(gimport.new_with_exposing(sch_parts, exposing))
  use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
  use _ <- gmod.with_import(
    gimport.new_with_exposing(
      ["gleam", "option"],
      "type Option, None, Some",
    ),
  )
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "result"]))
  use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
  case schema_context.schema_uses_calendar_date(def) {
    False -> inner()
    True -> {
      use _ <- gmod.with_import(
        gimport.new_with_exposing(["gleam", "time", "calendar"], "type Date"),
      )
      inner()
    }
  }
}

pub fn with_facade_module_imports(
  migration_path: String,
  db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let mig_parts = string.split(migration_path, "/")
  let db_parts = string.split(db_module_path, "/")
  let sch_parts = string.split(schema_path, "/")
  let row_parts = list.append(db_parts, ["row"])
  let get_parts = list.append(db_parts, ["get"])
  let upsert_parts = list.append(db_parts, ["upsert"])
  let delete_parts = list.append(db_parts, ["delete"])
  let query_parts = list.append(db_parts, ["query"])
  use _ <- gmod.with_import(gimport.new(mig_parts))
  use _ <- gmod.with_import(gimport.new_predefined(row_parts))
  use _ <- gmod.with_import(gimport.new_predefined(get_parts))
  use _ <- gmod.with_import(gimport.new_predefined(upsert_parts))
  use _ <- gmod.with_import(gimport.new_predefined(delete_parts))
  use _ <- gmod.with_import(gimport.new_predefined(query_parts))
  use _ <- gmod.with_import(gimport.new_with_exposing(sch_parts, exposing))
  use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
  use _ <- gmod.with_import(
    gimport.new_with_exposing(
      ["gleam", "option"],
      "type Option, None, Some",
    ),
  )
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "result"]))
  use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
  case schema_context.schema_uses_calendar_date(def) {
    False -> inner()
    True -> {
      use _ <- gmod.with_import(
        gimport.new_with_exposing(
          ["gleam", "time", "calendar"],
          "type Date, Date as CalDate, month_from_int, month_to_int",
        ),
      )
      inner()
    }
  }
}
