import dog_db/structure

pub fn dog_field_sql(field: structure.DogField) -> String {
  case field {
    structure.NameField -> "name"
    structure.AgeField -> "age"
    structure.IsNeuteredField -> "is_neutered"
    structure.IdField -> "id"
    structure.CreatedAtField -> "created_at"
    structure.UpdatedAtField -> "updated_at"
    structure.DeletedAtField -> "deleted_at"
  }
}
