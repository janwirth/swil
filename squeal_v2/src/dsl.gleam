import gleam/option.{type Option}
import gleam/time/calendar.{type Date}
import gleam/time/timestamp.{type Timestamp}

// these functions implementations are expanded into individual queries when done
// idempotent migrations _may_ work

pub fn age(t: Date) -> Int {
  todo("Implement on SQL level")
}

pub type Mutual(a, attributes) {
  Mutual(item: a)
  // maps to same field
}

pub type MutualWith(a, attributes) {
  MutualWith(item: a, attributes: Option(attributes))
}

pub type BelongsTo(a) {
  BelongsTo(item: a)
}

pub type BelongsToWith(a, attributes) {
  BelongsToWith(item: a, attributes: Option(attributes))
}

pub type Backlink(kind) {
  Backlink(items: List(kind))
}

pub type BacklinkWith(kind, attributes) {
  BacklinkWith(items: List(kind), attributes: Option(attributes))
}

pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
  todo
}

pub fn nullable(some_val: option.Option(some_type)) -> some_type {
  todo
}

// then it generates a query that just writes sql amd has a decoder for the right fields

// pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
//     todo
// }
// it's just querying that needs new generators.... Maybe it's better to just generate the plain values

// use proper migrations?
// o

// composing queries
pub type Query(type_, shape, order_field) {
  Query(
    shape: shape,
    filter: Option(Bool),
    order: #(order_field, Direction),
  )
}

pub type MagicFields {
  MagicFields(
    id: Int,
    created_at: Timestamp,
    updated_at: Timestamp,
    deleted_at: Option(Timestamp),
  )
}

pub type Direction {
  Asc
  Desc
}

pub fn order_by(field: field, direction: Direction) -> #(field, Direction) {
  #(field, direction)
}
