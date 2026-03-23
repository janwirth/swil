import gleam/option.{type Option, None, Some}

import cats_schema_generated/structure.{
  type CatField,
  AgeField,
  CreatedAtField,
  DeletedAtField,
  IdField,
  NameField,
  UpdatedAtField,
}
import gen/filter

pub fn cat_field_sql(field: CatField) -> String {
  case field {
    NameField -> "name"
    AgeField -> "age"
    IdField -> "id"
    CreatedAtField -> "created_at"
    UpdatedAtField -> "updated_at"
    DeletedAtField -> "deleted_at"
  }
}

pub fn sort_clause(sort: Option(filter.SortOrder(CatField))) -> String {
  case sort {
    None -> ""
    Some(filter.Asc(f)) -> " order by " <> cat_field_sql(f) <> " asc"
    Some(filter.Desc(f)) -> " order by " <> cat_field_sql(f) <> " desc"
  }
}
