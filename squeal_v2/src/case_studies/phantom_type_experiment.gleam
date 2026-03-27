

type Query (root, filter, order, shape) {

}

type NotDefined

type Defined(a)

type DuplicateFilterDefined(a)


fn query(root: root) -> Query(root, NotDefined, NotDefined, NotDefined) {
}

fn filter(q: Query(root, NotDefined, NotDefined, shape), filter: Bool) -> Query(root, DuplicateFilterDefined(filter), order, shape) { 
}

fn order(q: Query(root, filter, NotDefined, shape), order: order) -> Query(root, filter, Defined(order), shape) { 
}

fn shape(q: Query(root, filter, order, NotDefined), shape: shape) -> Query(root, filter, order, Defined(shape)) { 
}

const x = 21

fn my_query() {
    query(x)
    |> filter(x == 2)
    // |> filter(x == 3)
    |> order(x == 2)
    // |> shape(x == 2)
}