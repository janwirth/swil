import gleam/option.{type Option}

import help/identity
pub type Dog {
  Dog(name: Option(String), age: Option(Int), is_neutered: Option(Bool))
}

pub fn identities(dog: Dog) {
  [identity.Identity2(dog.name, dog.is_neutered)]
}
