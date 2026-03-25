pub type Schema {

  Schema(
    tables: List(Table),
  )
}
pub type Table {
  Table(
    name: String,
    columns: List(Column),
  )
}
pub type Column {
  Column(
    name: String,
    type_: String,
  )
}
pub type Relation {
  Relation(
    table: String,
    column: String,
  )
}

pub fn parse(schema: String) -> Schema {
    todo("Implement parse")
}

pub fn generate(schema: Schema, skeleton_only: Bool) -> String {
    // skeleton only will generate the skeleton code for the schema
    todo("Implement generate")
}