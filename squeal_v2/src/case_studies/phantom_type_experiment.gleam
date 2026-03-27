

type Query (root, filter, order, shape) {

}

type NotDefined

type Defined(a)

type DuplicateFilterDefined(a)

type DuplicateOrderDefined(a)

type DuplicateShapeDefined(a)

fn query(root: root) -> Query(root, NotDefined, NotDefined, NotDefined) {
}

fn filter_bool(q: Query(root, NotDefined, NotDefined, shape), filter: Bool) -> Query(root, DuplicateFilterDefined(filter), order, shape) { 
}

fn filter_complex(q: Query(root, NotDefined, NotDefined, shape), filter: Bool) -> Query(root, DuplicateFilterDefined(filter), order, shape) { 
}

fn order(q: Query(root, filter, NotDefined, shape), order: order) -> Query(root, filter, DuplicateOrderDefined(order), shape) { 
}

fn shape(q: Query(root, filter, order, NotDefined), shape: shape) -> Query(root, filter, order, DuplicateShapeDefined(shape)) { 
}

const x = 21

fn my_query() {
    query(x)
    |> filter_bool(x == 2)
    // |> filter(x == 3)
    |> order(x == 2)
    |> shape(x == 2)
    // |> shape(x == 2)
}