import dsl/dsl as dsl
import gleam/option.{type Option, None, Some}

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
  max_price: Float,
  fruit: Fruit,
) -> dsl.Query(Fruit, Fruit, Option(Float)) {
  dsl.Query(
    shape: fruit,
    filter: Some(dsl.Predicate(
      dsl.exclude_if_missing(fruit.price) <. max_price,
    )),
    order: dsl.order_by(fruit.price, dsl.Asc),
  )
}
