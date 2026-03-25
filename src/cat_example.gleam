import cat_db/crud as cats_crud
import cat_db/entry.{type FilterableCat} as cats
import cat_db/structure.{Num}
import gleam/option.{None, Some}
import help/filter.{NotContains, Gt, Lt}
import sqlight

pub fn cat_is_young(cat: FilterableCat) {
  Lt(cat.age, Num())
}

pub fn cat_older_than(age: Int) -> cats_crud.Filter {
  fn(cat: cats.FilterableCat) {
    Gt(left: cat.age, right: structure.NumValue(value: age))
  }
}

pub fn cat_age_eq(age: Int) {
  fn(cat: FilterableCat) {
    Eq(left: cat.age, right: structure.NumValue(value: age))
  }
}

pub fn cat_name_excludes(substr: String) -> cats_crud.Filter {
  fn(cat: cats.FilterableCat) {
    NotContains(
      haystack: cat.name,
      needle: structure.StringValue(value: substr),
    )
  }
}

// 
pub fn cat_older_than_and_name_excludes(age: Int, substr: String) -> Filter {
  fn(cat: cats.FilterableCat) {
    let age_filter = Gt(left: cat.age, right: structure.NumValue(value: age))
    let name_filter = NotContains(
        haystack: cat.name,
        needle: structure.StringValue(value: substr),
      )
    And([
      age_filter, name_filter
    ])

  }
}

pub fn main() -> Nil {
  use conn <- sqlight.with_connection(":memory:")
  let arg = cats_crud.filter_arg(Some(cat_older_than(6)), None)
  let _ = cats.cats(conn).migrate()
  let _cats = cats.cats(conn).read_many(arg)

  let best = cat_db.select
    |> filter(cat_is_young)
    |> sort(by_age_asc)
    |> load(cat_db.rel.friends)
  Nil
}

pub type Query(base, output) {
  Query(filter, sort, output_load)
}
// we have to go with optional fields - where we laod a list
// extending the struct doesn't work. We could, however, add tuples...
// hmmm


pub fn load_friends(q: Query(Cat, shape)) -> Query(Cat, #(shape, loaded)) {
  // add function to load chain
  // when execing queries consider
  // add to parser chain then


}

// this is then transpiled
// pub fn with_old_friends() {
//   let today = 100000 // assumiing years to num
//   select()
//     |> filter(fn (cat) {and([cat.age > 20, cat.friend.age > 20, cat.friend.$since])}) 
//     |> sort(fn(cat) #(cat.age, desc))
//     |> load(fn (cat) [cat.friend])
//   // generates SQL and a parser
// }



// pub fn by_age_asc(cat: FilterableCat) {
//   #(cat.age, Asc)
// }
