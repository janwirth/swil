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
        use _ <- gmod.with_import(gimport.new_with_exposing(
          ["gleam", "time", "calendar"],
          "type Date, Date as CalDate, month_from_int, month_to_int",
        ))
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
  use _ <- gmod.with_import(gimport.new_with_exposing(
    ["gleam", "option"],
    "type Option, None, Some",
  ))
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "result"]))
  after_result()
}

pub fn with_row_module_imports(
  _db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  _exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  use _ <- gmod.with_import(gimport.new_predefined(["api_help"]))
  use _ <- gmod.with_import(gimport.new_predefined(sch_parts))
  use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
  use _ <- gmod.with_import(
    gimport.new_predefined(["gleam", "dynamic", "decode"]),
  )
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "option"]))
  let with_optional_json = fn() {
    case schema_context.schema_uses_non_enum_scalars(def) {
      True ->
        gmod.with_import(gimport.new_predefined(["gleam", "json"]), fn(_) {
          inner()
        })
      False -> inner()
    }
  }
  with_optional_json()
}

pub fn with_upsert_module_imports(
  db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  _exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  let db_parts = string.split(db_module_path, "/")
  let row_parts = list.append(db_parts, ["row"])
  use _ <- gmod.with_import(gimport.new_predefined(row_parts))
  use _ <- gmod.with_import(gimport.new_predefined(["api_help"]))
  use _ <- gmod.with_import(gimport.new_predefined(sch_parts))
  use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "option"]))
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "result"]))
  use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
  case schema_context.schema_uses_calendar_date(def) {
    False -> {
      case schema_context.schema_uses_timestamp(def) {
        True ->
          gmod.with_import(
            gimport.new_predefined(["gleam", "time", "timestamp"]),
            fn(_) { inner() },
          )
        False -> inner()
      }
    }
    True -> {
      use _ <- gmod.with_import(
        gimport.new_predefined(["gleam", "time", "calendar"]),
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
        gimport.new_predefined(["gleam", "time", "calendar"]),
      )
      inner()
    }
  }
}

pub fn with_query_module_imports(
  db_module_path: String,
  schema_path: String,
  _def: SchemaDefinition,
  _exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  let db_parts = string.split(db_module_path, "/")
  let row_parts = list.append(db_parts, ["row"])
  use _ <- gmod.with_import(gimport.new_predefined(row_parts))
  use _ <- gmod.with_import(gimport.new_predefined(sch_parts))
  use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
  use _ <- gmod.with_import(gimport.new_predefined(["gleam", "option"]))
  use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
  inner()
}

pub fn with_get_module_imports(
  db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  _exposing: String,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  let sch_parts = string.split(schema_path, "/")
  let db_parts = string.split(db_module_path, "/")
  let row_parts = list.append(db_parts, ["row"])
  let finish = fn() {
    use _ <- gmod.with_import(gimport.new_predefined(row_parts))
    use _ <- gmod.with_import(gimport.new_predefined(sch_parts))
    use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
    use _ <- gmod.with_import(gimport.new_predefined(["gleam", "option"]))
    use _ <- gmod.with_import(gimport.new_predefined(["gleam", "result"]))
    use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
    case schema_context.schema_uses_calendar_date(def) {
      False -> inner()
      True -> {
        use _ <- gmod.with_import(
          gimport.new_predefined(["gleam", "time", "calendar"]),
        )
        inner()
      }
    }
  }
  case schema_context.schema_uses_calendar_date(def) {
    True ->
      gmod.with_import(gimport.new_predefined(["api_help"]), fn(_) { finish() })
    False -> finish()
  }
}

pub fn with_facade_module_imports(
  migration_path: String,
  db_module_path: String,
  schema_path: String,
  def: SchemaDefinition,
  _exposing: String,
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
  let needs_row = schema_context.api_facade_imports_row_module(def)
  let after_submodules = fn() {
    use _ <- gmod.with_import(gimport.new_predefined(sch_parts))
    use _ <- gmod.with_import(gimport.new_with_alias(["dsl", "dsl"], "dsl"))
    use _ <- gmod.with_import(gimport.new_predefined(["gleam", "option"]))
    use _ <- gmod.with_import(gimport.new_predefined(["sqlight"]))
    case schema_context.schema_uses_calendar_date(def) {
      False -> inner()
      True -> {
        use _ <- gmod.with_import(
          gimport.new_predefined(["gleam", "time", "calendar"]),
        )
        inner()
      }
    }
  }
  let after_row_optional = fn() {
    use _ <- gmod.with_import(gimport.new_predefined(get_parts))
    use _ <- gmod.with_import(gimport.new_predefined(upsert_parts))
    use _ <- gmod.with_import(gimport.new_predefined(delete_parts))
    use _ <- gmod.with_import(gimport.new_predefined(query_parts))
    after_submodules()
  }
  use _ <- gmod.with_import(gimport.new(mig_parts))
  case needs_row {
    True ->
      gmod.with_import(gimport.new_predefined(row_parts), fn(_) {
        after_row_optional()
      })
    False -> after_row_optional()
  }
}
