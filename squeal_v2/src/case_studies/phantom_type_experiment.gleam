pub type Query(root, filter, order, shape) {
}

pub type NotDefined

pub type Defined(a)

pub type DuplicateFilterDefined(a)

pub type DuplicateOrderDefined(a)

pub type DuplicateShapeDefined(a)

pub fn query(_root: root) -> Query(root, NotDefined, NotDefined, NotDefined) {
  panic as "phantom type experiment"
}

pub fn filter_bool(_q: Query(root, NotDefined, NotDefined, shape), _filter: Bool) -> Query(root, DuplicateFilterDefined(_filter), order, shape) { 
  panic as "phantom type experiment"
}

pub fn filter_complex(_q: Query(root, NotDefined, NotDefined, shape), _filter: Bool) -> Query(root, DuplicateFilterDefined(_filter), order, shape) { 
  panic as "phantom type experiment"
}

pub fn order(_q: Query(root, filter, NotDefined, shape), _order: order) -> Query(root, filter, DuplicateOrderDefined(_order), shape) { 
  panic as "phantom type experiment"
}

pub fn shape(_q: Query(root, filter, order, NotDefined), _shape: shape) -> Query(root, filter, order, DuplicateShapeDefined(_shape)) { 
  panic as "phantom type experiment"
}

pub fn my_query() {
  query(21)
  |> filter_bool(False)
  |> order(False)
  |> shape(False)
}