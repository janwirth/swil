import dog_db/structure.{
  type DogField, AgeField, CreatedAtField, DeletedAtField, IdField,
  IsNeuteredField, NameField, UpdatedAtField,
}

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
