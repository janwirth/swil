import gleam/option.{type Option, None, Some}

import dog_db/structure.{
  type DogField, AgeField, CreatedAtField, DeletedAtField, IdField,
  IsNeuteredField, NameField, UpdatedAtField,
}
import help/filter

pub fn dog_field_sql(field: DogField) -> String {
  case field {
    NameField -> "name"
    AgeField -> "age"
    IsNeuteredField -> "is_neutered"
    IdField -> "id"
    CreatedAtField -> "created_at"
    UpdatedAtField -> "updated_at"
    DeletedAtField -> "deleted_at"
  }
}

pub fn sort_clause(sort: Option(filter.SortOrder(DogField))) -> String {
  case sort {
    None -> ""
    Some(filter.Asc(f)) -> " order by " <> dog_field_sql(f) <> " asc"
    Some(filter.Desc(f)) -> " order by " <> dog_field_sql(f) <> " desc"
  }
}
