import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}

pub type CalendarDate {
  CalendarDate(year: Int, month: Int, day: Int)
}

// these functions implementations are expanded into individual queries when done
// idempotent migrations _may_ work


pub fn age(t: CalendarDate) -> Int {
  todo("Implement on SQL level")
}

pub type Mutual(a) {
  Mutual(item: a)
  // maps to same field
}

pub type BelongsTo(a) {
  BelongsTo(item: a)
}

pub type Backlink(kind) {
  Backlink(items: List(kind))
  // auto-resolves BUT only one is allowed per pair
}

pub type Direction {
  Asc
  Desc
}


pub type Identity(a, b, c) {
  Identity(a)
  Identity2(a, b)
  Identity3(a, b, c)
}

pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
  todo
}

pub fn nullable(some_val: option.Option(some_type)) -> some_type {
  todo
}

pub type Date
// then it generates a query that just writes sql amd has a decoder for the right fields

// pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
//     todo
// }
// it's just querying that needs new generators.... Maybe it's better to just generate the plain values

// use proper migrations?
// o

// composing queries
pub type Query(type_, shape, order) {
      Query(
    shape: Option(shape),
    filter: Option(Bool),
    order: Option(#(Direction, order)),
  )
}

pub type MagicFields {
  MagicFields(id: Int, created_at: Timestamp, updated_at: Timestamp, deleted_at: Option(Timestamp))
}