import case_studies/library_manager_db/migration
import case_studies/library_manager_schema as lm
import dsl/dsl as dsl
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import sqlight

/// Exercises nested [`library_manager_schema.FilterScalar`](library_manager_schema.FilterScalar) trees
/// compiled through [`library_manager_schema.filter_by_tag`](library_manager_schema.filter_by_tag) into
/// [`dsl.BooleanFilter`](dsl.BooleanFilter), then evaluated with [`dsl.eval_boolean_filter`](dsl.eval_boolean_filter).
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
  let assert True = filt == Some(True)
  let assert True = shape == None
  let #(ord_field, ord_dir) = order
  let assert True = ord_field == magic.updated_at
  let assert True = ord_dir == dsl.Desc
}

// --- SQLite: load trackbuckets + test-only join table, evaluate filters on hydrated rows ---

const join_table_sql = "create table trackbucket_tag (
  trackbucket_id integer not null,
  tag_id integer not null,
  weight integer not null,
  primary key (trackbucket_id, tag_id)
);"

const insert_tag_sql = "insert into tag (label, emoji, created_at, updated_at, deleted_at)
values (?, ?, ?, ?, null) returning id;"

const insert_trackbucket_sql = "insert into trackbucket (title, artist, created_at, updated_at, deleted_at)
values (?, ?, ?, ?, null) returning id;"

const insert_assoc_sql = "insert into trackbucket_tag (trackbucket_id, tag_id, weight) values (?, ?, ?);"

const load_buckets_tags_sql = "select tb.id, tb.title, tb.artist, tb.created_at, tb.updated_at, tb.deleted_at,
  tt.tag_id, tt.weight
from trackbucket tb
left join trackbucket_tag tt on tt.trackbucket_id = tb.id
where tb.deleted_at is null
order by tb.id, tt.tag_id;"

type LoadRow {
  LoadRow(
    bucket_id: Int,
    title: String,
    artist: String,
    created_s: Int,
    updated_s: Int,
    deleted_raw: Option(Int),
    tag_id: Option(Int),
    weight: Option(Int),
  )
}

type BucketAcc {
  BucketAcc(
    id: Int,
    title: String,
    artist: String,
    created_s: Int,
    updated_s: Int,
    deleted_raw: Option(Int),
    tags: List(#(Int, Int)),
  )
}

fn insert_tag_id(conn: sqlight.Connection, label: String, ts: Int) -> Result(Int, sqlight.Error) {
  use rows <- result.try(sqlight.query(
    insert_tag_sql,
    on: conn,
    with: [
      sqlight.text(label),
      sqlight.text(""),
      sqlight.int(ts),
      sqlight.int(ts),
    ],
    expecting: {
      use id <- decode.field(0, decode.int)
      decode.success(id)
    },
  ))
  case rows {
    [id, ..] -> Ok(id)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "insert tag returned no id",
        -1,
      ))
  }
}

fn insert_trackbucket_id(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  ts: Int,
) -> Result(Int, sqlight.Error) {
  use rows <- result.try(sqlight.query(
    insert_trackbucket_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
      sqlight.int(ts),
      sqlight.int(ts),
    ],
    expecting: {
      use id <- decode.field(0, decode.int)
      decode.success(id)
    },
  ))
  case rows {
    [id, ..] -> Ok(id)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "insert trackbucket returned no id",
        -1,
      ))
  }
}

fn insert_assoc(
  conn: sqlight.Connection,
  trackbucket_id: Int,
  tag_id: Int,
  weight: Int,
) -> Result(Nil, sqlight.Error) {
  use _rows <- result.try(sqlight.query(
    insert_assoc_sql,
    on: conn,
    with: [
      sqlight.int(trackbucket_id),
      sqlight.int(tag_id),
      sqlight.int(weight),
    ],
    expecting: decode.success(Nil),
  ))
  Ok(Nil)
}

fn load_row_decoder() -> decode.Decoder(LoadRow) {
  use bucket_id <- decode.field(0, decode.int)
  use title <- decode.field(1, decode.string)
  use artist <- decode.field(2, decode.string)
  use created_s <- decode.field(3, decode.int)
  use updated_s <- decode.field(4, decode.int)
  use deleted_raw <- decode.field(5, decode.optional(decode.int))
  use tag_id <- decode.field(6, decode.optional(decode.int))
  use weight <- decode.field(7, decode.optional(decode.int))
  decode.success(LoadRow(
    bucket_id:,
    title:,
    artist:,
    created_s:,
    updated_s:,
    deleted_raw:,
    tag_id:,
    weight:,
  ))
}

fn fold_load_row(d: Dict(Int, BucketAcc), r: LoadRow) -> Dict(Int, BucketAcc) {
  case dict.get(d, r.bucket_id) {
    Ok(acc) -> {
      let tags = case r.tag_id, r.weight {
        Some(tid), Some(w) -> [#(tid, w), ..acc.tags]
        _, _ -> acc.tags
      }
      dict.insert(d, r.bucket_id, BucketAcc(..acc, tags:))
    }
    Error(Nil) -> {
      let tags = case r.tag_id, r.weight {
        Some(tid), Some(w) -> [#(tid, w)]
        _, _ -> []
      }
      dict.insert(d, r.bucket_id, BucketAcc(
        id: r.bucket_id,
        title: r.title,
        artist: r.artist,
        created_s: r.created_s,
        updated_s: r.updated_s,
        deleted_raw: r.deleted_raw,
        tags:,
      ))
    }
  }
}

fn acc_to_bucket_pair(acc: BucketAcc) -> #(lm.TrackBucket, dsl.MagicFields) {
  let magic =
    dsl.MagicFields(
      id: acc.id,
      created_at: timestamp.from_unix_seconds(acc.created_s),
      updated_at: timestamp.from_unix_seconds(acc.updated_s),
      deleted_at: case acc.deleted_raw {
        Some(s) -> Some(timestamp.from_unix_seconds(s))
        None -> None
      },
    )
  let bucket =
    lm.TrackBucket(
      title: Some(acc.title),
      artist: Some(acc.artist),
      matched_tracks: [],
      tags: list.reverse(acc.tags),
      identities: lm.ByBucketTitleAndArtist(title: acc.title, artist: acc.artist),
    )
  #(bucket, magic)
}

fn load_trackbuckets_with_tags(
  conn: sqlight.Connection,
) -> Result(List(#(lm.TrackBucket, dsl.MagicFields)), sqlight.Error) {
  use flat <- result.try(sqlight.query(
    load_buckets_tags_sql,
    on: conn,
    with: [],
    expecting: load_row_decoder(),
  ))
  let folded = list.fold(flat, dict.new(), fold_load_row)
  dict.values(folded)
  |> list.sort(fn(a, b) { int.compare(a.id, b.id) })
  |> list.map(acc_to_bucket_pair)
  |> Ok()
}

/// Migrates a real SQLite db (`:memory:`), adds a **test-only** `trackbucket_tag` join table
/// (not yet in the pragma migration), inserts tags and buckets, then checks that
/// [`filter_by_tag`](library_manager_schema.filter_by_tag) matches rows loaded from SQL.
pub fn library_manager_complex_filter_sqlite_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = migration.migration(conn)
  let assert Ok(Nil) = sqlight.exec(join_table_sql, conn)

  let ts = 1700
  let assert Ok(id_a) = insert_tag_id(conn, "lm_e2e_tag_a", ts)
  let assert Ok(id_b) = insert_tag_id(conn, "lm_e2e_tag_b", ts)
  let assert Ok(id_c) = insert_tag_id(conn, "lm_e2e_tag_c", ts)

  let assert Ok(b1) = insert_trackbucket_id(conn, "Album1", "Artist1", ts)
  let assert Ok(b2) = insert_trackbucket_id(conn, "Album2", "Artist2", ts)

  let assert Ok(Nil) = insert_assoc(conn, b1, id_a, 1)
  let assert Ok(Nil) = insert_assoc(conn, b1, id_b, 3)
  let assert Ok(Nil) = insert_assoc(conn, b1, id_c, 0)
  let assert Ok(Nil) = insert_assoc(conn, b2, id_a, 1)

  let assert Ok(loaded) = load_trackbuckets_with_tags(conn)
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
