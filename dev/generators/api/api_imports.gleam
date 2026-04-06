import generators/api/schema_context
import gleam/list
import gleam/string
import gleamgen/import_ as gimport
import gleamgen/module as gmod
import schema_definition/schema_definition.{type SchemaDefinition}

fn import_pre(path: List(String)) -> gimport.ImportedModule {
  gimport.new(path)
  |> gimport.with_predefined(True)
}

fn import_pre_alias(path: List(String), alias: String) -> gimport.ImportedModule {
  gimport.new(path)
  |> gimport.with_alias(alias)
  |> gimport.with_predefined(True)
}

fn import_pre_exposing(path: List(String), exposing: String) -> gimport.ImportedModule {
  gimport.new(path)
  |> gimport.with_exposing(exposing_items(exposing))
  |> gimport.with_predefined(True)
}

fn first_grapheme_is_uppercase(s: String) -> Bool {
  case string.first(s) {
    Error(Nil) -> False
    Ok(g) -> g == string.uppercase(g) && g != string.lowercase(g)
  }
}

fn parse_exposing_piece(piece: String) -> gimport.ExposedItem {
  let t = string.trim(piece)
  case string.starts_with(t, "type ") {
    True -> {
      let rest = string.drop_start(t, 5)
      case string.split_once(rest, " as ") {
        Ok(#(name, alias)) ->
          gimport.exposed_type_as(string.trim(name), string.trim(alias))
        Error(Nil) -> gimport.exposed_type(string.trim(rest))
      }
    }
    False ->
      case string.split_once(t, " as ") {
        Ok(#(left, right)) ->
          case first_grapheme_is_uppercase(left) {
            True -> gimport.exposed_type_as(left, right)
            False -> gimport.exposed_value_as(left, right)
          }
        Error(Nil) -> gimport.exposed_value(t)
      }
  }
}

fn exposing_items(s: String) -> List(gimport.ExposedItem) {
  string.split(s, ", ")
  |> list.map(parse_exposing_piece)
}

fn with_gleam_timestamp_type_if_needed(
  def: SchemaDefinition,
  inner: fn() -> gmod.Module,
) -> gmod.Module {
  case schema_context.schema_uses_timestamp(def) {
    True ->
      gmod.with_import(
        import_pre_exposing(["gleam", "time", "timestamp"], "type Timestamp"),
        fn(_) { inner() },
      )
    False -> inner()
  }
}

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
        with_gleam_timestamp_type_if_needed(def, fn() {
          use _ <- gmod.with_import(import_pre(["sqlight"]))
          inner()
        })
      True -> {
        use _ <- gmod.with_import(import_pre(["gleam", "int"]))
        use _ <- gmod.with_import(import_pre(["gleam", "string"]))
        use _ <- gmod.with_import(
          import_pre_exposing(
            ["gleam", "time", "calendar"],
            "type Date, Date as CalDate, month_from_int, month_to_int",
          ),
        )
        with_gleam_timestamp_type_if_needed(def, fn() {
          use _ <- gmod.with_import(import_pre(["sqlight"]))
          inner()
        })
      }
    }
  }
  use _ <- gmod.with_import(gimport.new(mig_parts))
  use _ <- gmod.with_import(import_pre(["swil", "runtime", "api_help"]))
  use _ <- gmod.with_import(import_pre_exposing(sch_parts, exposing))
  use _ <- gmod.with_import(import_pre_alias(["swil", "dsl"], "dsl"))
  use _ <- gmod.with_import(import_pre(["gleam", "dynamic", "decode"]))
  use _ <- gmod.with_import(
    import_pre_exposing(["gleam", "option"], "type Option, None, Some"),
  )
  use _ <- gmod.with_import(import_pre(["gleam", "result"]))
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
  use _ <- gmod.with_import(import_pre(["swil", "runtime", "api_help"]))
  use _ <- gmod.with_import(import_pre(sch_parts))
  use _ <- gmod.with_import(import_pre_alias(["swil", "dsl"], "dsl"))
  use _ <- gmod.with_import(
    import_pre(["gleam", "dynamic", "decode"]),
  )
  use _ <- gmod.with_import(import_pre(["gleam", "option"]))
  let with_optional_json = fn() {
    case schema_context.schema_uses_non_enum_scalars(def) {
      True ->
        gmod.with_import(import_pre(["gleam", "json"]), fn(_) {
          inner()
        })
      False -> inner()
    }
  }
  with_optional_json()
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
  use _ <- gmod.with_import(import_pre(row_parts))
  use _ <- gmod.with_import(import_pre(sch_parts))
  use _ <- gmod.with_import(import_pre_alias(["swil", "dsl"], "dsl"))
  use _ <- gmod.with_import(import_pre(["gleam", "option"]))
  use _ <- gmod.with_import(import_pre(["sqlight"]))
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
    use _ <- gmod.with_import(import_pre(row_parts))
    use _ <- gmod.with_import(import_pre(sch_parts))
    use _ <- gmod.with_import(import_pre_alias(["swil", "dsl"], "dsl"))
    use _ <- gmod.with_import(import_pre(["gleam", "option"]))
    use _ <- gmod.with_import(import_pre(["gleam", "result"]))
    use _ <- gmod.with_import(import_pre(["sqlight"]))
    case schema_context.schema_uses_calendar_date(def) {
      False -> inner()
      True -> {
        use _ <- gmod.with_import(
          import_pre(["gleam", "time", "calendar"]),
        )
        inner()
      }
    }
  }
  case schema_context.schema_uses_calendar_date(def) {
    True ->
      gmod.with_import(import_pre(["swil", "runtime", "api_help"]), fn(_) {
        finish()
      })
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
  let cmd_parts = list.append(db_parts, ["cmd"])
  let query_parts = list.append(db_parts, ["query"])
  let needs_row = schema_context.api_facade_imports_row_module(def)
  let after_submodules = fn() {
    use _ <- gmod.with_import(import_pre(sch_parts))
    use _ <- gmod.with_import(import_pre_alias(["swil", "dsl"], "dsl"))
    use _ <- gmod.with_import(import_pre(["gleam", "option"]))
    use _ <- gmod.with_import(import_pre(["sqlight"]))
    case schema_context.schema_uses_calendar_date(def) {
      False -> inner()
      True -> {
        use _ <- gmod.with_import(
          import_pre(["gleam", "time", "calendar"]),
        )
        inner()
      }
    }
  }
  let after_row_optional = fn() {
    use _ <- gmod.with_import(import_pre(get_parts))
    use _ <- gmod.with_import(import_pre(cmd_parts))
    use _ <- gmod.with_import(import_pre(query_parts))
    after_submodules()
  }
  use _ <- gmod.with_import(gimport.new(mig_parts))
  case needs_row {
    True ->
      gmod.with_import(import_pre(row_parts), fn(_) {
        after_row_optional()
      })
    False -> after_row_optional()
  }
}
