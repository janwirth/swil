pub opaque type Identified(by) {}

pub opaque type ByName {}

pub opaque type ByFruit {}

pub opaque type MyFruit(id) {}

pub fn insert(fruit: MyFruit(Identified(id))) {

}
