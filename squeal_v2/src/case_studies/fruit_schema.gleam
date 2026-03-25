import gleam/option

pub type Fruit {
  Fruit(
    name: option.Option(String),
    color: option.Option(String),
    price: option.Option(Float),
    quantity: option.Option(Int),
    identities: FruitIdentities,
  )
}

pub type FruitIdentities {
  ByName(name: String)
}
