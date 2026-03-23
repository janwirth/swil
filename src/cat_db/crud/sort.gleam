import cat_db/structure.{
  type CatField, AgeField, CreatedAtField, DeletedAtField, IdField, NameField,
  UpdatedAtField,
}

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
