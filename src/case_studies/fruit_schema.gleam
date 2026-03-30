import skwil/dsl/dsl
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

pub fn query_cheap_fruit(
  fruit: Fruit,
  _magic_fields: dsl.MagicFields,
  max_price: Float,
) {
  dsl.query(fruit)
  |> dsl.shape(fruit)
  |> dsl.filter_bool(dsl.exclude_if_missing(fruit.price) <. max_price)
  |> dsl.order(fruit.price, dsl.Asc)
}
