import cat_db/crud as cats_crud
import cat_db/entry as cats
import cat_db/structure.{IntVal, StrVal}
import gleam/option.{None, Some}
import help/filter.{And, Eq, Gt, NotContains}
import sqlight

pub fn cat_older_than(age: Int) -> cats_crud.Filter {
  fn(cat: cats.FilterableCat) { Gt(left: cat.age, right: IntVal(value: age)) }
}

pub fn cat_age_eq(age: Int) -> cats_crud.Filter {
  fn(cat: cats.FilterableCat) { Eq(left: cat.age, right: IntVal(value: age)) }
}

pub fn cat_name_excludes(substr: String) -> cats_crud.Filter {
  fn(cat: cats.FilterableCat) {
    NotContains(haystack: cat.name, needle: StrVal(value: substr))
  }
}

pub fn cat_older_than_and_name_excludes(
  age: Int,
  substr: String,
) -> cats_crud.Filter {
  fn(cat: cats.FilterableCat) {
    let age_filter = Gt(left: cat.age, right: IntVal(value: age))
    let name_filter =
      NotContains(haystack: cat.name, needle: StrVal(value: substr))
    And(wheres: [age_filter, name_filter])
  }
}

pub fn main() -> Nil {
  use conn <- sqlight.with_connection(":memory:")
  let arg = cats_crud.filter_arg(Some(cat_older_than(6)), None)
  let _ = cats.cats(conn).migrate()
  let _cats = cats.cats(conn).read_many(arg)
  Nil
}
