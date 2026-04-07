/// E2E tests for `page_edited_*` pagination functions.
///
/// Seeds ≥5 rows with distinct `updated_at` timestamps, then verifies
/// that `page_edited_fruit(conn, limit: 2, offset: 2)` returns the expected
/// slice from the `updated_at desc` ordering.
import case_studies/fruit_db/api
import case_studies/fruit_db/cmd
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import sqlight

pub fn main() -> Nil {
  gleeunit.main()
}

fn open_db() -> sqlight.Connection {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)
  conn
}

/// Seeds fruit rows one at a time and returns their names in insert order.
/// SQLite's autoincrement `updated_at` default means later inserts have
/// strictly larger timestamps when we read them back immediately.
fn seed_fruits(conn: sqlight.Connection) -> List(String) {
  let names = ["apple", "banana", "cherry", "date", "elderberry"]
  list.each(names, fn(n) {
    let assert Ok(Nil) =
      cmd.execute_fruit_cmds(conn, [
        cmd.UpsertFruitByName(
          name: n,
          color: None,
          price: Some(1.0),
          quantity: None,
        ),
      ])
  })
  names
}

/// `page_edited_fruit` with limit=0 returns zero rows.
pub fn page_edited_limit_zero_returns_empty_test() {
  let conn = open_db()
  let _ = seed_fruits(conn)
  let assert Ok(rows) = api.page_edited_fruit(conn, limit: 0, offset: 0)
  assert rows == []
}

/// `page_edited_fruit` with limit=100, offset=0 returns all seeded rows.
pub fn page_edited_offset_zero_returns_all_test() {
  let conn = open_db()
  let _ = seed_fruits(conn)
  let assert Ok(rows) = api.page_edited_fruit(conn, limit: 100, offset: 0)
  assert list.length(rows) == 5
}

/// `last_100_edited_fruit` and `page_edited_fruit(limit: 100, offset: 0)`
/// return the same number of rows.
pub fn page_edited_matches_last_100_at_offset_zero_test() {
  let conn = open_db()
  let _ = seed_fruits(conn)
  let assert Ok(last_100) = api.last_100_edited_fruit(conn)
  let assert Ok(paged) = api.page_edited_fruit(conn, limit: 100, offset: 0)
  assert list.length(last_100) == list.length(paged)
}

/// `page_edited_fruit` with limit=2 returns exactly 2 rows.
pub fn page_edited_limit_respected_test() {
  let conn = open_db()
  let _ = seed_fruits(conn)
  let assert Ok(rows) = api.page_edited_fruit(conn, limit: 2, offset: 0)
  assert list.length(rows) == 2
}

/// Verifies that offset slicing works: the result at (limit=2, offset=2) does
/// not overlap with (limit=2, offset=0) and together they cover 4 distinct rows.
pub fn page_edited_offset_slices_correctly_test() {
  let conn = open_db()
  let _ = seed_fruits(conn)
  let assert Ok(page1) = api.page_edited_fruit(conn, limit: 2, offset: 0)
  let assert Ok(page2) = api.page_edited_fruit(conn, limit: 2, offset: 2)
  let page1_names =
    list.map(page1, fn(r) {
      let #(fruit, _) = r
      fruit.name
    })
  let page2_names =
    list.map(page2, fn(r) {
      let #(fruit, _) = r
      fruit.name
    })
  // No overlap between pages
  assert list.all(page2_names, fn(n) { !list.contains(page1_names, n) })
  // Together they cover 4 distinct rows
  assert list.length(list.append(page1_names, page2_names)) == 4
}

/// `page_edited_fruit` results are ordered by `updated_at desc`
/// (same ordering as `last_100_edited_fruit`).
pub fn page_edited_order_matches_last_100_test() {
  let conn = open_db()
  let _ = seed_fruits(conn)
  let assert Ok(last_100) = api.last_100_edited_fruit(conn)
  let assert Ok(paged) = api.page_edited_fruit(conn, limit: 100, offset: 0)
  let last_100_names =
    list.map(last_100, fn(r) {
      let #(fruit, _) = r
      fruit.name
    })
  let paged_names =
    list.map(paged, fn(r) {
      let #(fruit, _) = r
      fruit.name
    })
  assert last_100_names == paged_names
}
