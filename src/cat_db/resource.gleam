import gleam/option.{type Option}

pub type Cat {
  Cat(name: Option(String), age: Option(Int))
}

pub type CatForUpsert {
  CatWithName(name: String, age: Option(Int))
}

pub fn cat_with_name(name: String, age: Option(Int)) -> CatForUpsert {
  CatWithName(name:, age:)
}
