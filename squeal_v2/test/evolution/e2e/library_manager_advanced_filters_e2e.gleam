//// End-to-end tests for the complex `BooleanFilter` query pipeline.
////
//// Uses a real in-memory SQLite database.  Exercises:
////   0. Post-migration `pragma index_list` / `pragma index_info` — core unique indexes; `trackbucket_tag` has perf index `(trackbucket_id, tag_id, value)` plus implicit UNIQUE on `(trackbucket_id, tag_id)`.
////   1. `migration.migration` — creates all tables including `trackbucket_tag`.
////   2. `migration.upsert_trackbucket_tag` — inserts junction rows with edge attributes.
////   3. `query.query_tracks_by_view_config` — filters via `BooleanFilter(TagExpressionScalar)`.
////   4. Boolean combinators: `And`, `Or`, `Not`, `Predicate`.
////   5. All four leaf constructors: `Has`, `IsAtLeast`, `IsAtMost`, `IsEqualTo`.
////   6. JSON round-trip via `filter_expression_decoder`.

import case_studies/library_manager_advanced_db/api
import case_studies/library_manager_advanced_db/migration
import case_studies/library_manager_advanced_db/query
import case_studies/library_manager_advanced_schema as schema
import dsl/dsl
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import sql/pragma_assert
import sqlight

// =============================================================================
// Setup helpers
// =============================================================================

fn open_db() -> sqlight.Connection {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)
  conn
}

// Expected `pragma index_list` / `pragma index_info` TSV after `migration.migration`
// (same shape as `sql/pragma_assert`).

const expected_importedtrack_index_list = "seq	name	unique	origin	partial
0	importedtrack_by_title_artist	1	c	0"

const expected_importedtrack_index_info = "seqno	cid	name
0	1	title
1	2	artist"

const expected_tab_index_list = "seq	name	unique	origin	partial
0	tab_by_label	1	c	0"

const expected_tab_index_info = "seqno	cid	name
0	1	label"

const expected_tag_index_list = "seq	name	unique	origin	partial
0	tag_by_label	1	c	0"

const expected_tag_index_info = "seqno	cid	name
0	1	label"

const expected_trackbucket_index_list = "seq	name	unique	origin	partial
0	trackbucket_by_title_artist	1	c	0"

const expected_trackbucket_index_info = "seqno	cid	name
0	1	title
1	2	artist"

const expected_trackbucket_tag_index_list = "seq	name	unique	origin	partial
0	trackbucket_tag_by_trackbucket_id_tag_id_value	0	c	0
1	sqlite_autoindex_trackbucket_tag_1	1	u	0"

const expected_trackbucket_tag_perf_index_info = "seqno	cid	name
0	0	trackbucket_id
1	1	tag_id
2	2	value"

const expected_trackbucket_tag_unique_index_info = "seqno	cid	name
0	0	trackbucket_id
1	1	tag_id"

fn assert_index_list_and_info(
  conn: sqlight.Connection,
  table: String,
  expected_list: String,
  index_name: String,
  expected_info: String,
) -> Nil {
  let assert Ok(got_list) = pragma_assert.index_list_tsv(conn, table)
  let assert Ok(got_info) = pragma_assert.index_info_tsv(conn, index_name)
  let assert True = got_list == expected_list
  let assert True = got_info == expected_info
  Nil
}

// =============================================================================
// 0. Indices after migration (pragma snapshots)
// =============================================================================

pub fn migration_user_tables_include_junction_test() {
  let conn = open_db()
  let assert Ok(names) = pragma_assert.user_table_names(conn)
  let want = ["importedtrack", "tab", "tag", "trackbucket", "trackbucket_tag"]
  let assert True = list.sort(names, string.compare) == want
}

pub fn migration_indices_importedtrack_test() {
  let conn = open_db()
  assert_index_list_and_info(
    conn,
    "importedtrack",
    expected_importedtrack_index_list,
    "importedtrack_by_title_artist",
    expected_importedtrack_index_info,
  )
}

pub fn migration_indices_tab_test() {
  let conn = open_db()
  assert_index_list_and_info(
    conn,
    "tab",
    expected_tab_index_list,
    "tab_by_label",
    expected_tab_index_info,
  )
}

pub fn migration_indices_tag_test() {
  let conn = open_db()
  assert_index_list_and_info(
    conn,
    "tag",
    expected_tag_index_list,
    "tag_by_label",
    expected_tag_index_info,
  )
}

pub fn migration_indices_trackbucket_test() {
  let conn = open_db()
  assert_index_list_and_info(
    conn,
    "trackbucket",
    expected_trackbucket_index_list,
    "trackbucket_by_title_artist",
    expected_trackbucket_index_info,
  )
}

pub fn migration_indices_trackbucket_tag_test() {
  let conn = open_db()
  let assert Ok(got_list) = pragma_assert.index_list_tsv(conn, "trackbucket_tag")
  let assert True = got_list == expected_trackbucket_tag_index_list
  let assert Ok(got_perf) =
    pragma_assert.index_info_tsv(
      conn,
      "trackbucket_tag_by_trackbucket_id_tag_id_value",
    )
  let assert True = got_perf == expected_trackbucket_tag_perf_index_info
  let assert Ok(got_unique) =
    pragma_assert.index_info_tsv(conn, "sqlite_autoindex_trackbucket_tag_1")
  let assert True = got_unique == expected_trackbucket_tag_unique_index_info
}

fn id_decoder() -> decode.Decoder(Int) {
  use id <- decode.field(0, decode.int)
  decode.success(id)
}

/// Insert a tag row; return its auto-generated id.
fn insert_tag(conn: sqlight.Connection, label: String) -> Int {
  let assert Ok(rows) =
    sqlight.query(
      "insert into \"tag\" (\"label\", \"emoji\", \"created_at\", \"updated_at\") values (?, '', ?, ?) returning \"id\"",
      on: conn,
      with: [sqlight.text(label), sqlight.int(0), sqlight.int(0)],
      expecting: id_decoder(),
    )
  let assert [id] = rows
  id
}

/// Insert a trackbucket row; return its auto-generated id.
fn insert_trackbucket(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Int {
  let assert Ok(rows) =
    sqlight.query(
      "insert into \"trackbucket\" (\"title\", \"artist\", \"created_at\", \"updated_at\") values (?, ?, ?, ?) returning \"id\"",
      on: conn,
      with: [
        sqlight.text(title),
        sqlight.text(artist),
        sqlight.int(0),
        sqlight.int(0),
      ],
      expecting: id_decoder(),
    )
  let assert [id] = rows
  id
}

// =============================================================================
// 1. Has — basic EXISTS match
// =============================================================================

pub fn has_matches_tagged_bucket_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "chill")
  let tb_id = insert_trackbucket(conn, "Mellow Mix", "Various")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_id, None)
  let filter = dsl.Predicate(schema.Has(tag_id: tag_id))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert list.length(results) == 1
  let assert [#(tb, _)] = results
  assert tb.title == Some("Mellow Mix")
}

pub fn has_no_match_when_tag_absent_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "energetic")
  let _tb_id = insert_trackbucket(conn, "Calm Vibes", "Various")
  // No junction row — bucket should NOT appear.
  let filter = dsl.Predicate(schema.Has(tag_id: tag_id))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert results == []
}

// =============================================================================
// 2. IsAtLeast — edge attribute value >= threshold
// =============================================================================

pub fn is_at_least_matches_when_value_ge_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "priority")
  let tb_id = insert_trackbucket(conn, "Top Picks", "Curator")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_id, Some(80))
  let filter = dsl.Predicate(schema.IsAtLeast(tag_id: tag_id, value: 50))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert list.length(results) == 1
}

pub fn is_at_least_no_match_when_value_lt_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "priority2")
  let tb_id = insert_trackbucket(conn, "Low Prio", "Curator")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_id, Some(20))
  let filter = dsl.Predicate(schema.IsAtLeast(tag_id: tag_id, value: 50))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert results == []
}

// =============================================================================
// 3. IsAtMost — edge attribute value <= threshold
// =============================================================================

pub fn is_at_most_matches_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "bpm")
  let tb_id = insert_trackbucket(conn, "Slow Jams", "DJ Mellow")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_id, Some(90))
  let filter = dsl.Predicate(schema.IsAtMost(tag_id: tag_id, value: 100))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert list.length(results) == 1
}

pub fn is_at_most_no_match_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "bpm_high")
  let tb_id = insert_trackbucket(conn, "Fast Bangers", "DJ Speed")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_id, Some(150))
  let filter = dsl.Predicate(schema.IsAtMost(tag_id: tag_id, value: 100))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert results == []
}

// =============================================================================
// 4. IsEqualTo — exact value match
// =============================================================================

pub fn is_equal_to_matches_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "rating")
  let tb_id = insert_trackbucket(conn, "Gold", "Label")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_id, Some(5))
  let filter = dsl.Predicate(schema.IsEqualTo(tag_id: tag_id, value: 5))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert list.length(results) == 1
}

pub fn is_equal_to_no_match_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "rating2")
  let tb_id = insert_trackbucket(conn, "Silver", "Label")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_id, Some(4))
  let filter = dsl.Predicate(schema.IsEqualTo(tag_id: tag_id, value: 5))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert results == []
}

// =============================================================================
// 5. AND combinator
// =============================================================================

pub fn and_matches_when_both_satisfied_test() {
  let conn = open_db()
  let tag_a = insert_tag(conn, "lofi")
  let tag_b = insert_tag(conn, "study")
  let tb_id = insert_trackbucket(conn, "Study Lofi", "Playlist")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_a, None)
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_b, None)
  let filter =
    dsl.And([
      dsl.Predicate(schema.Has(tag_id: tag_a)),
      dsl.Predicate(schema.Has(tag_id: tag_b)),
    ])
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert list.length(results) == 1
}

pub fn and_no_match_when_one_missing_test() {
  let conn = open_db()
  let tag_a = insert_tag(conn, "jazz")
  let tag_b = insert_tag(conn, "blues")
  let tb_id = insert_trackbucket(conn, "Jazz Only", "Playlist")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_a, None)
  // tag_b NOT attached
  let filter =
    dsl.And([
      dsl.Predicate(schema.Has(tag_id: tag_a)),
      dsl.Predicate(schema.Has(tag_id: tag_b)),
    ])
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert results == []
}

// =============================================================================
// 6. OR combinator
// =============================================================================

pub fn or_matches_when_either_satisfied_test() {
  let conn = open_db()
  let tag_rock = insert_tag(conn, "rock")
  let tag_pop = insert_tag(conn, "pop")
  let tb_rock = insert_trackbucket(conn, "Rock Anthology", "Label")
  let tb_pop = insert_trackbucket(conn, "Pop Hits", "Label")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_rock, tag_rock, None)
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_pop, tag_pop, None)
  let filter =
    dsl.Or([
      dsl.Predicate(schema.Has(tag_id: tag_rock)),
      dsl.Predicate(schema.Has(tag_id: tag_pop)),
    ])
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert list.length(results) == 2
}

// =============================================================================
// 7. NOT combinator
// =============================================================================

pub fn not_excludes_tagged_bucket_test() {
  let conn = open_db()
  let tag_nsfw = insert_tag(conn, "nsfw")
  let tb_flagged = insert_trackbucket(conn, "Adult Mix", "Label")
  let tb_clean = insert_trackbucket(conn, "Clean Mix", "Label")
  // Only "Adult Mix" is tagged; "Clean Mix" is not.
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_flagged, tag_nsfw, None)
  let filter = dsl.Not(dsl.Predicate(schema.Has(tag_id: tag_nsfw)))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  // Only "Clean Mix" passes the NOT filter
  assert list.length(results) == 1
  let assert [#(tb, _)] = results
  assert tb.title == Some("Clean Mix")
  let _ = tb_clean
}

// =============================================================================
// 8. NULL edge attribute — excluded by 3VL
// =============================================================================

pub fn is_at_least_excludes_null_value_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "weight")
  let tb_id = insert_trackbucket(conn, "Unweighted", "Various")
  // value is NULL
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_id, tag_id, None)
  let filter = dsl.Predicate(schema.IsAtLeast(tag_id: tag_id, value: 0))
  // NULL >= 0 is UNKNOWN in SQL 3VL → row excluded
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert results == []
}

// =============================================================================
// 9. JSON round-trip via filter_expression_decoder
// =============================================================================

pub fn json_has_round_trip_test() {
  // Encode a `Has` filter as JSON and decode it back.
  let json_str =
    "{\"tag\":\"Predicate\",\"item\":{\"tag\":\"Has\",\"tag_id\":42}}"
  let assert Ok(filter) =
    json.parse(from: json_str, using: query.filter_expression_decoder())
  let assert dsl.Predicate(schema.Has(tag_id: 42)) = filter
}

pub fn json_and_round_trip_test() {
  let json_str =
    "{\"tag\":\"And\",\"exprs\":["
    <> "{\"tag\":\"Predicate\",\"item\":{\"tag\":\"Has\",\"tag_id\":1}},"
    <> "{\"tag\":\"Predicate\",\"item\":{\"tag\":\"IsAtLeast\",\"tag_id\":2,\"value\":10}}"
    <> "]}"
  let assert Ok(filter) =
    json.parse(from: json_str, using: query.filter_expression_decoder())
  let assert dsl.And([
    dsl.Predicate(schema.Has(tag_id: 1)),
    dsl.Predicate(schema.IsAtLeast(tag_id: 2, value: 10)),
  ]) = filter
}

pub fn json_not_round_trip_test() {
  let json_str =
    "{\"tag\":\"Not\",\"expr\":{\"tag\":\"Predicate\",\"item\":{\"tag\":\"Has\",\"tag_id\":7}}}"
  let assert Ok(filter) =
    json.parse(from: json_str, using: query.filter_expression_decoder())
  let assert dsl.Not(dsl.Predicate(schema.Has(tag_id: 7))) = filter
}

// =============================================================================
// 10. Multiple buckets — only matching ones returned
// =============================================================================

pub fn filter_returns_only_matching_rows_test() {
  let conn = open_db()
  let tag_id = insert_tag(conn, "featured")
  let tb_yes = insert_trackbucket(conn, "Featured Album", "Artist A")
  let _tb_no = insert_trackbucket(conn, "Regular Album", "Artist B")
  let assert Ok(Nil) =
    migration.upsert_trackbucket_tag(conn, tb_yes, tag_id, None)
  let filter = dsl.Predicate(schema.Has(tag_id: tag_id))
  let assert Ok(results) = api.query_tracks_by_view_config(conn, filter)
  assert list.length(results) == 1
  let assert [#(tb, _)] = results
  assert tb.title == Some("Featured Album")
}
