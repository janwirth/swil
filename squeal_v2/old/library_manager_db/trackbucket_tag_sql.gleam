/// Case-study helpers for the `trackbucket_tag` link table and tag-weight loaders.
/// Not emitted by `generate_api`; kept here until migrations own this DDL.

import case_studies/library_manager_schema.{type TrackBucket, TrackBucket, ByBucketTitleAndArtist}
import dsl/dsl as dsl
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import sqlight

const trackbucket_tag_table_sql = "create table if not exists trackbucket_tag (
  trackbucket_id integer not null,
  tag_id integer not null,
  weight integer not null,
  primary key (trackbucket_id, tag_id)
);"

const insert_tag_returning_id_sql = "insert into tag (label, emoji, created_at, updated_at, deleted_at)
values (?, ?, ?, ?, null) returning id;"

const insert_trackbucket_returning_id_sql = "insert into trackbucket (title, artist, created_at, updated_at, deleted_at)
values (?, ?, ?, ?, null) returning id;"

const insert_trackbucket_tag_sql = "insert into trackbucket_tag (trackbucket_id, tag_id, weight) values (?, ?, ?);"

const load_trackbuckets_tags_sql = "select tb.id, tb.title, tb.artist, tb.created_at, tb.updated_at, tb.deleted_at,
  tt.tag_id, tt.weight
from trackbucket tb
left join trackbucket_tag tt on tt.trackbucket_id = tb.id
where tb.deleted_at is null
order by tb.id, tt.tag_id;"

type TrackbucketTagLoadRow {
  TrackbucketTagLoadRow(
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

type TrackbucketTagAcc {
  TrackbucketTagAcc(
    id: Int,
    title: String,
    artist: String,
    created_s: Int,
    updated_s: Int,
    deleted_raw: Option(Int),
    tags: List(#(Int, Int)),
  )
}

/// Ensures the `trackbucket_tag` link table exists (`trackbucket_id`, `tag_id`, `weight`).
pub fn ensure_trackbucket_tag_table(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  sqlight.exec(trackbucket_tag_table_sql, conn)
}

pub fn insert_tag_row_returning_id(
  conn: sqlight.Connection,
  label: String,
  created_epoch_s: Int,
) -> Result(Int, sqlight.Error) {
  use rows <- result.try(sqlight.query(
    insert_tag_returning_id_sql,
    on: conn,
    with: [
      sqlight.text(label),
      sqlight.text(""),
      sqlight.int(created_epoch_s),
      sqlight.int(created_epoch_s),
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

pub fn insert_trackbucket_row_returning_id(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  created_epoch_s: Int,
) -> Result(Int, sqlight.Error) {
  use rows <- result.try(sqlight.query(
    insert_trackbucket_returning_id_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
      sqlight.int(created_epoch_s),
      sqlight.int(created_epoch_s),
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

pub fn insert_trackbucket_tag(
  conn: sqlight.Connection,
  trackbucket_id: Int,
  tag_id: Int,
  weight: Int,
) -> Result(Nil, sqlight.Error) {
  use _rows <- result.try(sqlight.query(
    insert_trackbucket_tag_sql,
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

fn trackbucket_tag_load_row_decoder() -> decode.Decoder(TrackbucketTagLoadRow) {
  use bucket_id <- decode.field(0, decode.int)
  use title <- decode.field(1, decode.string)
  use artist <- decode.field(2, decode.string)
  use created_s <- decode.field(3, decode.int)
  use updated_s <- decode.field(4, decode.int)
  use deleted_raw <- decode.field(5, decode.optional(decode.int))
  use tag_id <- decode.field(6, decode.optional(decode.int))
  use weight <- decode.field(7, decode.optional(decode.int))
  decode.success(TrackbucketTagLoadRow(
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

fn fold_trackbucket_tag_row(
  d: Dict(Int, TrackbucketTagAcc),
  r: TrackbucketTagLoadRow,
) -> Dict(Int, TrackbucketTagAcc) {
  case dict.get(d, r.bucket_id) {
    Ok(acc) -> {
      let tags = case r.tag_id, r.weight {
        Some(tid), Some(w) -> [#(tid, w), ..acc.tags]
        _, _ -> acc.tags
      }
      dict.insert(d, r.bucket_id, TrackbucketTagAcc(..acc, tags:))
    }
    Error(Nil) -> {
      let tags = case r.tag_id, r.weight {
        Some(tid), Some(w) -> [#(tid, w)]
        _, _ -> []
      }
      dict.insert(d, r.bucket_id, TrackbucketTagAcc(
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

fn trackbucket_acc_to_pair(
  acc: TrackbucketTagAcc,
) -> #(TrackBucket, dsl.MagicFields) {
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
    TrackBucket(
      title: Some(acc.title),
      artist: Some(acc.artist),
      matched_tracks: [],
      tags: list.reverse(acc.tags),
      identities: ByBucketTitleAndArtist(title: acc.title, artist: acc.artist),
    )
  #(bucket, magic)
}

/// Loads every non-deleted trackbucket with `(tag_id, weight)` pairs from `trackbucket_tag`.
pub fn load_trackbuckets_with_tag_weights(
  conn: sqlight.Connection,
) -> Result(List(#(TrackBucket, dsl.MagicFields)), sqlight.Error) {
  use flat <- result.try(sqlight.query(
    load_trackbuckets_tags_sql,
    on: conn,
    with: [],
    expecting: trackbucket_tag_load_row_decoder(),
  ))
  let folded = list.fold(flat, dict.new(), fold_trackbucket_tag_row)
  dict.values(folded)
  |> list.sort(fn(a, b) { int.compare(a.id, b.id) })
  |> list.map(trackbucket_acc_to_pair)
  |> Ok()
}
