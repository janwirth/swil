type MyDataType = #(String, String)
fn makerow_example(label: String, value: String) -> MyDataType {
    #(label, value)
}

fn insert_many_example(items: List(a), cb: fn(label: String, value: String) -> MyDataType) -> List(MyDataType) {
  let rows = list.map(items, fn(item) {
    cb(item)
  })
  rows
}


fn makerow_by_label_and_value(label: String, value: String) -> fn(label: String, value: String) -> MyDataType {
    fn(label, value) {
        #(label, value)
    }
}

type Identified(by) = {}

type ByName = {}

type ByFruit = {}

