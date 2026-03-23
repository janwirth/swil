import gleam/option.{type Option}

import help/identity

pub type Cat {
  Cat(name: Option(String), age: Option(Int))
}

pub fn identities(cat: Cat) {
  [identity.Identity(cat.name)]
}
