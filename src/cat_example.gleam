import cat_db/crud as cats_crud
import cat_db/entry as cats
import help/filter
import sqlight
import gleam/option.{Some, None}
import cat_db/structure




// only supports optional fields
// runtime code can handle defaults

// hand-written queries with generated query builder
pub fn cat_older_than(age: Int) -> cats_crud.Filter {
    fn (cat: cats.FilterableCat) {
        filter.Gt(left: cat.age, right: structure.NumValue(value: age))
    }
}

pub fn cat_age_eq(age: Int) -> cats_crud.Filter {
    fn(cat: cats.FilterableCat) {
        filter.Eq(left: cat.age, right: structure.NumValue(value: age))
    }
}


pub fn cat_name_excludes(substr: String) -> cats_crud.Filter {
    fn(cat: cats.FilterableCat) {
        filter.NotContains(left: cat.name, right: structure.StringValue(value: substr))
    }
}
// make this type genriic and more comfortable to type

pub fn cat_older_than_and_name_excludes(
    age: Int,
    substr: String,
) -> Filter {
    fn(cat: cats.FilterableCat) {
        filter.And(
            left: filter.Gt(left: cat.age, right: structure.NumValue(value: age)),
            right: filter.NotContains(left: cat.name, right: structure.StringValue(value: substr)),
        )
    }
}

pub type Filter = cats_crud.Filter

pub fn main() -> Nil {
  use conn <- sqlight.with_connection(":memory:")
  let arg = cats_crud.filter_arg(Some(cat_older_than(6)), None)
  let _ = cats.cats(conn).migrate()
  let cats = cats.cats(conn).read_many(arg)

  Nil
}
