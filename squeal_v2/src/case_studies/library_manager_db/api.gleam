import case_studies/library_manager_db/migration
import case_studies/library_manager_schema.{type ImportedTrack, ByFilePath, ByTitleAndArtist, ImportedTrack}
import dsl/dsl as dsl
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import sqlight

// --- SQL (importedtrack table shape matches `example_migration_importedtrack` / pragma migrations) ---
//
// insert into importedtrack (title, artist, file_path, created_at, updated_at, deleted_at)
//   values (?, ?, ?, ?, ?, null)
//   on conflict(title, artist) do update set
//     file_path = excluded.file_path,
//     updated_at = excluded.updated_at,
//     deleted_at = null;
//
// select title, artist, file_path, id, created_at, updated_at, deleted_at from importedtrack
//   where title = ? and artist = ? and deleted_at is null;
//
// update importedtrack set file_path = ?, updated_at = ?
//   where title = ? and artist = ? and deleted_at is null
//   returning title, artist, file_path, id, created_at, updated_at, deleted_at;
//
// update importedtrack set deleted_at = ?, updated_at = ?
//   where title = ? and artist = ? and deleted_at is null
//   returning title, artist;
//
// select title, artist, file_path, id, created_at, updated_at, deleted_at from importedtrack
//   where deleted_at is null
//   order by updated_at desc
//   limit 100;

const upsert_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"file_path\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"title\", \"artist\") do update set
  \"file_path\" = excluded.\"file_path\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null
returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const select_by_title_and_artist_sql = "select \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const update_by_title_and_artist_sql = "update \"importedtrack\" set \"file_path\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null returning \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\";"

const soft_delete_by_title_and_artist_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null returning \"title\", \"artist\";"

const last_100_sql = "select \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

fn unix_seconds_now() -> Int {
  let #(s, _) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds
  s
}

fn opt_text_for_db(o: Option(String)) -> String {
  case o {
    Some(s) -> s
    None -> ""
  }
}

fn opt_string_from_db(s: String) -> Option(String) {
  case s {
    "" -> None
    _ -> Some(s)
  }
}

fn magic_from_db_row(
  id: Int,
  created_s: Int,
  updated_s: Int,
  deleted_raw: Option(Int),
) -> dsl.MagicFields {
  dsl.MagicFields(
    id:,
    created_at: timestamp.from_unix_seconds(created_s),
    updated_at: timestamp.from_unix_seconds(updated_s),
    deleted_at: case deleted_raw {
      Some(s) -> Some(timestamp.from_unix_seconds(s))
      None -> None
    },
  )
}

fn importedtrack_with_magic_row_decoder() -> decode.Decoder(#(ImportedTrack, dsl.MagicFields)) {
  use title <- decode.field(0, decode.string)
  use artist <- decode.field(1, decode.string)
  use file_path <- decode.field(2, decode.string)
  use id <- decode.field(3, decode.int)
  use created_at <- decode.field(4, decode.int)
  use updated_at <- decode.field(5, decode.int)
  use deleted_at_raw <- decode.field(6, decode.optional(decode.int))
  let importedtrack =
    ImportedTrack(
      title: Some(title),
      artist: Some(artist),
      file_path: opt_string_from_db(file_path),
      tags: [],
      identities: ByTitleAndArtist(title:, artist:),
    )
  decode.success(#(
    importedtrack,
    magic_from_db_row(id, created_at, updated_at, deleted_at_raw),
  ))
}

fn not_found_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "importedtrack not found: " <> op, -1)
}

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

/// Upsert a importedtrack by the `ByTitleAndArtist` identity.
pub fn upsert_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  let now = unix_seconds_now()
  let c = opt_text_for_db(file_path)
  use rows <- result.try(sqlight.query(
    upsert_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
      sqlight.text(c),
      sqlight.int(now),
      sqlight.int(now),
    ],
    expecting: importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(row)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "upsert returned no row",
        -1,
      ))
  }
}

/// Get a importedtrack by the `ByTitleAndArtist` identity.
pub fn get_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Option(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    select_by_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(title),
      sqlight.text(artist),
    ],
    expecting: importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [] -> Ok(None)
    [row, ..] -> Ok(Some(row))
  }
}

/// Update a importedtrack by the `ByTitleAndArtist` identity.
pub fn update_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
  file_path: Option(String),
) -> Result(#(ImportedTrack, dsl.MagicFields), sqlight.Error) {
  let now = unix_seconds_now()
  let c = opt_text_for_db(file_path)
  use rows <- result.try(sqlight.query(
    update_by_title_and_artist_sql,
    on: conn,
    with: [
      sqlight.text(c),
      sqlight.int(now),
      sqlight.text(title),
      sqlight.text(artist),
    ],
    expecting: importedtrack_with_magic_row_decoder(),
  ))
  case rows {
    [row, ..] -> Ok(row)
    [] -> Error(not_found_error("update_importedtrack_by_title_and_artist"))
  }
}

/// Delete a importedtrack by the `ByTitleAndArtist` identity.
pub fn delete_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title: String,
  artist: String,
) -> Result(Nil, sqlight.Error) {
  let now = unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_by_title_and_artist_sql,
      on: conn,
      with: [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(title),
        sqlight.text(artist),
      ],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_error("delete_importedtrack_by_title_and_artist"))
  }
}

/// List up to 100 recently edited importedtrack rows.
pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(List(#(ImportedTrack, dsl.MagicFields)), sqlight.Error) {
  sqlight.query(
    last_100_sql,
    on: conn,
    with: [],
    expecting: importedtrack_with_magic_row_decoder(),
  )
}
