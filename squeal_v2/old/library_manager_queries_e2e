import case_studies/library_manager_db/api
import case_studies/library_manager_db/trackbucket_tag_sql as trackbucket_tag_sql
import case_studies/library_manager_schema as lm
import dsl/dsl as dsl
import gleam/list
import gleam/string
import gleam/option.{None, Some}
import gleam/time/timestamp
import sqlight

/// Exercises nested [`library_manager_schema.FilterScalar`](library_manager_schema.FilterScalar) trees
/// compiled through [`library_manager_schema.filter_by_tag`](library_manager_schema.filter_by_tag) into
/// [`dsl.BooleanFilter`](dsl.BooleanFilter). Queries use [`dsl.SqlWhere`](dsl.SqlWhere) from
/// [`dsl.boolean_filter_tag_join_sql`](dsl.boolean_filter_tag_join_sql); in-memory checks use
/// [`dsl.eval_boolean_filter`](dsl.eval_boolean_filter).
pub fn library_manager_complex_filter_e2e_test() {
  let bucket =
    lm.TrackBucket(
      title: None,
      artist: None,
      matched_tracks: [],
      tags: [#(10, 1), #(20, 3), #(30, 0)],
      identities: lm.ByBucketTitleAndArtist(
        title: "t",
        artist: "a",
      ),
    )

  let assert True =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.TagExpression(tag_id: 10, operator: lm.Has),
    ))
  let assert False =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.TagExpression(tag_id: 99, operator: lm.Has),
    ))
  let assert True =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.TagExpression(tag_id: 99, operator: lm.DoesNotHave),
    ))

  let assert True =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.TagExpression(tag_id: 20, operator: lm.IsAtLeast(value: 2)),
    ))
  let assert False =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.TagExpression(tag_id: 20, operator: lm.IsAtMost(value: 2)),
    ))
  let assert True =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.TagExpression(tag_id: 20, operator: lm.IsEqualTo(value: 3)),
    ))

  let assert True =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.And(exprs: [
        lm.TagExpression(tag_id: 10, operator: lm.Has),
        lm.TagExpression(tag_id: 20, operator: lm.Has),
      ]),
    ))
  let assert False =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.And(exprs: [
        lm.TagExpression(tag_id: 10, operator: lm.Has),
        lm.TagExpression(tag_id: 99, operator: lm.Has),
      ]),
    ))

  let assert True =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.Or(exprs: [
        lm.TagExpression(tag_id: 99, operator: lm.Has),
        lm.TagExpression(tag_id: 30, operator: lm.Has),
      ]),
    ))

  let assert False =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.Not(expr: lm.TagExpression(tag_id: 10, operator: lm.Has)),
    ))

  let assert True =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket,
      lm.Not(expr: lm.And(exprs: [
        lm.TagExpression(tag_id: 10, operator: lm.Has),
        lm.TagExpression(tag_id: 99, operator: lm.Has),
      ])),
    ))

  let magic =
    dsl.MagicFields(
      id: 1,
      created_at: timestamp.from_unix_seconds(0),
      updated_at: timestamp.from_unix_seconds(100),
      deleted_at: None,
    )
  let q =
    lm.query_tracks_by_filter(
      bucket,
      lm.And(exprs: [
        lm.TagExpression(tag_id: 20, operator: lm.IsAtLeast(value: 2)),
        lm.Not(expr: lm.TagExpression(tag_id: 99, operator: lm.Has)),
      ]),
      magic,
    )
  let dsl.Query(filter: filt, order:, shape:) = q
  let assert Some(dsl.SqlWhere(dsl.SqlFilter(where_sql:, int_params:))) =
    filt
  let assert True = string.contains(where_sql, "exists")
  let assert True = int_params != []
  let assert True = shape == None
  let #(ord_field, ord_dir) = order
  let assert True = ord_field == magic.updated_at
  let assert True = ord_dir == dsl.Desc
}

/// Uses [`trackbucket_tag_sql.ensure_trackbucket_tag_table`](trackbucket_tag_sql.ensure_trackbucket_tag_table) and loaders on a real SQLite connection.
pub fn library_manager_complex_filter_sqlite_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = api.migrate(conn)
  let assert Ok(Nil) = trackbucket_tag_sql.ensure_trackbucket_tag_table(conn)

  let ts = 1700
  let assert Ok(id_a) =
    trackbucket_tag_sql.insert_tag_row_returning_id(conn, "lm_e2e_tag_a", ts)
  let assert Ok(id_b) =
    trackbucket_tag_sql.insert_tag_row_returning_id(conn, "lm_e2e_tag_b", ts)
  let assert Ok(id_c) =
    trackbucket_tag_sql.insert_tag_row_returning_id(conn, "lm_e2e_tag_c", ts)

  let assert Ok(b1) =
    trackbucket_tag_sql.insert_trackbucket_row_returning_id(
      conn,
      "Album1",
      "Artist1",
      ts,
    )
  let assert Ok(b2) =
    trackbucket_tag_sql.insert_trackbucket_row_returning_id(
      conn,
      "Album2",
      "Artist2",
      ts,
    )

  let assert Ok(Nil) =
    trackbucket_tag_sql.insert_trackbucket_tag(conn, b1, id_a, 1)
  let assert Ok(Nil) =
    trackbucket_tag_sql.insert_trackbucket_tag(conn, b1, id_b, 3)
  let assert Ok(Nil) =
    trackbucket_tag_sql.insert_trackbucket_tag(conn, b1, id_c, 0)
  let assert Ok(Nil) =
    trackbucket_tag_sql.insert_trackbucket_tag(conn, b2, id_a, 1)

  let assert Ok(loaded) =
    trackbucket_tag_sql.load_trackbuckets_with_tag_weights(conn)
  let assert True = list.length(loaded) == 2

  let phantom = 9_999_999
  let complex_filter =
    lm.And(exprs: [
      lm.TagExpression(tag_id: id_b, operator: lm.IsAtLeast(value: 2)),
      lm.Not(expr: lm.TagExpression(tag_id: phantom, operator: lm.Has)),
    ])

  let titles_matching =
    list.filter(loaded, fn(pair) {
      let #(bucket, _) = pair
      dsl.eval_boolean_filter(lm.filter_by_tag(bucket, complex_filter))
    })
    |> list.map(fn(pair) {
      let #(bucket, _) = pair
      let assert Some(t) = bucket.title
      t
    })
  let assert True = titles_matching == ["Album1"]

  let #(bucket1, _) =
    list.find(loaded, fn(pair) {
      let #(b, _) = pair
      b.title == Some("Album1")
    })
    |> fn(x) {
      let assert Ok(p) = x
      p
    }

  let assert True =
    dsl.eval_boolean_filter(lm.filter_by_tag(
      bucket1,
      lm.Or(exprs: [
        lm.TagExpression(tag_id: phantom, operator: lm.Has),
        lm.TagExpression(tag_id: id_c, operator: lm.Has),
      ]),
    ))

  let assert Ok(Nil) = sqlight.close(conn)
}
