// Verifies that assert_pragma_snapshot tolerates index_info cid values that differ
// from the fixture because a column was added via ALTER TABLE ADD COLUMN (which always
// appends, shifting subsequent column cids relative to a fresh CREATE TABLE).
import sql/pragma_assert
import sqlight

// Schema: CREATE TABLE has (id, a, b, c) with index on (a, c).
// Old DB: created without column b, then b appended → a=cid1, c=cid2.
// Expected fixture: fresh CREATE TABLE → a=cid1, b=cid2, c=cid3.
// The index_info for (a, c) differs: got cids 1,2 vs expected 1,3.
pub fn index_info_cid_mismatch_due_to_alter_table_add_column_test() {
  let assert Ok(conn) = sqlight.open(":memory:")

  // Simulate the old schema (missing column b)
  let assert Ok(Nil) =
    sqlight.exec(
      "create table \"item\" (
        \"id\" integer primary key autoincrement not null,
        \"a\" text,
        \"c\" text,
        \"created_at\" integer not null
      );",
      conn,
    )

  // Add b via ALTER TABLE (appends at end, so b gets cid 4, not cid 2)
  let assert Ok(Nil) =
    sqlight.exec("alter table \"item\" add column \"b\" text;", conn)

  // Create the index on (a, c) — cids will be 1 and 2 (old positions)
  let assert Ok(Nil) =
    sqlight.exec(
      "create unique index item_by_a_c on \"item\"(\"a\", \"c\");",
      conn,
    )

  // Expected constants as they would appear in a fresh CREATE TABLE:
  // id(0), a(1), b(2), c(3), created_at(4)
  let expected_table_info =
    "cid	name	type	notnull	dflt_value	pk
0	id	INTEGER	1	NULL	1
1	a	TEXT	0	NULL	0
2	b	TEXT	0	NULL	0
3	c	TEXT	0	NULL	0
4	created_at	INTEGER	1	NULL	0"

  let expected_index_list =
    "seq	name	unique	origin	partial
0	item_by_a_c	1	c	0"

  // In the fixture, c is at cid 3 (its position in fresh CREATE TABLE).
  // In the actual DB, c is at cid 2 (original position, before b was appended).
  let expected_index_info =
    "seqno	cid	name
0	1	a
1	3	c"

  // assert_pragma_snapshot must not panic despite the cid mismatch in index_info.
  pragma_assert.assert_pragma_snapshot(
    conn,
    ["item"],
    "item",
    expected_table_info,
    expected_index_list,
    "item_by_a_c",
    expected_index_info,
  )

  let assert Ok(Nil) = sqlight.close(conn)
}
