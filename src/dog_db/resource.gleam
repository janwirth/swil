import gleam/option.{type Option}

pub type Dog {
  Dog(name: Option(String), age: Option(Int), is_neutered: Option(Bool))
}

pub type DogForUpsert {
  DogWithNameIsNeutered(name: String, age: Option(Int), is_neutered: Bool)
}

pub fn dog_with_name_is_neutered(name: String, age: Option(Int), is_neutered: Bool) -> DogForUpsert {
  DogWithNameIsNeutered(name:, age:, is_neutered:)
}
