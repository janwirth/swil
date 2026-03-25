import gleam/option

pub type CalendarDate {
    CalendarDate(year: Int, month: Int, day: Int)
}

// these functions implementations are expanded into individual queries when done
// idempotent migrations _may_ work

pub fn select(t: Query(t), cb: fn(t) -> selection) -> Query(t) {
    todo("This is just metaprogramming, don't execute")
}

pub fn query(t: t) -> Query(t) {
    todo("This is just metaprogramming, don't execute")
}
pub fn filter(t: Query(t), cb: fn(t) -> Bool) -> Query(t) {
    todo("This is just metaprogramming, don't execute")
}
pub fn sort(t: Query(t), cb: fn(t) -> #(a, Direction)) -> Query(t) {
    todo("This is just metaprogramming, don't execute")
}
pub fn age(t: CalendarDate) -> Int {
    todo("Implement on SQL level")
}


pub type Direction {
    Asc
    Desc
}

pub type Query(t) {}

pub type Identity(a,b,c) {
    Identity(a)
    Identity2(a,b)
    Identity3(a,b,c)
}

pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
    todo
}

pub fn nullable(some_val: option.Option(some_type)) -> some_type {
    todo
}

pub type Date {}




// then it generates a query that just writes sql amd has a decoder for the right fields

// pub fn exclude_if_missing(some_val: option.Option(some_type)) -> some_type {
//     todo
// }
// it's just querying that needs new generators.... Maybe it's better to just generate the plain values

// use proper migrations?
// o