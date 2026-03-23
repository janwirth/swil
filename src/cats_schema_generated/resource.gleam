import gleam/option.{type Option}

pub type Cat {
  Cat(name: Option(String), age: Option(Int))
}
