//// Schema migration for `library_manager_advanced_db`.
////
//// Creates all base entity tables plus the `trackbucket_tag` junction table
//// for the `TrackBucket ↔ Tag` many-to-many relationship with edge attributes
//// (`value: Option(Int)`).

import gleam/dynamic/decode
import gleam/result
import sqlight

// =============================================================================
// CREATE TABLE statements
// =============================================================================

const create_tag_sql = "create table if not exists \"tag\" (
  \"id\" integer primary key autoincrement not null,
  \"label\" text not null,
  \"emoji\" text not null,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_tag_label_index_sql = "create unique index if not exists tag_by_tag_label on \"tag\"(\"label\");"

const create_trackbucket_sql = "create table if not exists \"trackbucket\" (
  \"id\" integer primary key autoincrement not null,
  \"title\" text not null,
  \"artist\" text not null,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_trackbucket_title_artist_index_sql = "create unique index if not exists trackbucket_by_title_artist on \"trackbucket\"(\"title\", \"artist\");"

/// Junction table: `TrackBucket` ↔ `Tag` with `value: Option(Int)` edge attribute.
const create_trackbucket_tag_sql = "create table if not exists \"trackbucket_tag\" (
  \"id\" integer primary key autoincrement not null,
  \"trackbucket_id\" integer not null references \"trackbucket\"(\"id\"),
  \"tag_id\" integer not null references \"tag\"(\"id\"),
  \"value\" integer,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer,
  unique (\"trackbucket_id\", \"tag_id\")
);"

const create_trackbucket_tag_fk_indexes_sql = "create index if not exists trackbucket_tag_by_trackbucket on \"trackbucket_tag\"(\"trackbucket_id\");
create index if not exists trackbucket_tag_by_tag on \"trackbucket_tag\"(\"tag_id\");"

const create_importedtrack_sql = "create table if not exists \"importedtrack\" (
  \"id\" integer primary key autoincrement not null,
  \"title\" text not null,
  \"artist\" text not null,
  \"file_path\" text not null,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

const create_tab_sql = "create table if not exists \"tab\" (
  \"id\" integer primary key autoincrement not null,
  \"label\" text not null,
  \"order\" real not null,
  \"view_config\" text not null,
  \"created_at\" integer not null,
  \"updated_at\" integer not null,
  \"deleted_at\" integer
);"

// =============================================================================
// Public entry point
// =============================================================================

pub fn migration(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlight.exec(create_tag_sql, conn))
  use _ <- result.try(sqlight.exec(create_tag_label_index_sql, conn))
  use _ <- result.try(sqlight.exec(create_trackbucket_sql, conn))
  use _ <- result.try(sqlight.exec(
    create_trackbucket_title_artist_index_sql,
    conn,
  ))
  use _ <- result.try(sqlight.exec(create_trackbucket_tag_sql, conn))
  use _ <- result.try(sqlight.exec(create_trackbucket_tag_fk_indexes_sql, conn))
  use _ <- result.try(sqlight.exec(create_importedtrack_sql, conn))
  use _ <- result.try(sqlight.exec(create_tab_sql, conn))
  Ok(Nil)
}

// =============================================================================
// Junction row helpers
// =============================================================================

/// Insert or replace a `trackbucket_tag` edge.
pub fn upsert_trackbucket_tag(
  conn: sqlight.Connection,
  trackbucket_id: Int,
  tag_id: Int,
  value: sqlight.Value,
  now: Int,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlight.query(
    "insert into \"trackbucket_tag\"
      (\"trackbucket_id\", \"tag_id\", \"value\", \"created_at\", \"updated_at\")
      values (?, ?, ?, ?, ?)
      on conflict(\"trackbucket_id\", \"tag_id\") do update set
        \"value\" = excluded.\"value\",
        \"updated_at\" = excluded.\"updated_at\"",
    on: conn,
    with: [
      sqlight.int(trackbucket_id),
      sqlight.int(tag_id),
      value,
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: decode.success(Nil),
  ))
  Ok(Nil)
}
