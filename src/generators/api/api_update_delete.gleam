import generators/api/api_decoders as dec
import generators/sql_types
import schema_definition/schema_definition.{type FieldDefinition}

pub fn sql_bind_expr(
  f: FieldDefinition,
  value: String,
  _row_qualifier: String,
) -> String {
  case sql_types.sql_type(f.type_) {
    "int" -> "sqlight.int(" <> value <> ")"
    "real" -> "sqlight.float(" <> value <> ")"
    _ ->
      case dec.field_is_calendar_date(f) {
        True -> "sqlight.text(api_help.date_to_db_string(" <> value <> "))"
        False -> "sqlight.text(" <> value <> ")"
      }
  }
}
