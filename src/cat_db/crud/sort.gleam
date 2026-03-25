import cat_db/structure

pub fn cat_field_sql(field: structure.CatField) -> String {
  case field {
    structure.NameField -> "name"
    structure.AgeField -> "age"
    structure.IdField -> "id"
    structure.CreatedAtField -> "created_at"
    structure.UpdatedAtField -> "updated_at"
    structure.DeletedAtField -> "deleted_at"
  }
}
