import gleam/dynamic/decode
import gleam/result
import skwil/api_help
import sqlight

const soft_delete_tab_by_tab_label_sql = "update \"tab\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null returning \"label\";"

const soft_delete_trackbucket_by_bucket_title_and_artist_sql = "update \"trackbucket\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null returning \"title\", \"artist\";"

const soft_delete_tag_by_tag_label_sql = "update \"tag\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null returning \"label\";"

const soft_delete_importedtrack_by_file_path_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"file_path\" = ? and \"deleted_at\" is null returning \"file_path\";"

const soft_delete_importedtrack_by_title_and_artist_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null returning \"title\", \"artist\";"

/// Delete a tab by the `ByTabLabel` identity.
pub fn delete_tab_by_tab_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_tab_by_tab_label_sql,
      on: conn,
      with: [sqlight.int(now), sqlight.int(now), sqlight.text(label)],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_tab_tab_label_error("delete_tab_by_tab_label"))
  }
}

fn not_found_tab_tab_label_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "tab" <> " not found: " <> op, -1)
}

/// Delete a trackbucket by the `ByBucketTitleAndArtist` identity.
pub fn delete_trackbucket_by_bucket_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_trackbucket_by_bucket_title_and_artist_sql,
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
    [] ->
      Error(not_found_trackbucket_bucket_title_and_artist_error(
        "delete_trackbucket_by_bucket_title_and_artist",
      ))
  }
}

fn not_found_trackbucket_bucket_title_and_artist_error(
  op: String,
) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "trackbucket" <> " not found: " <> op,
    -1,
  )
}

/// Delete a tag by the `ByTagLabel` identity.
pub fn delete_tag_by_tag_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_tag_by_tag_label_sql,
      on: conn,
      with: [sqlight.int(now), sqlight.int(now), sqlight.text(label)],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] -> Error(not_found_tag_tag_label_error("delete_tag_by_tag_label"))
  }
}

fn not_found_tag_tag_label_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(sqlight.GenericError, "tag" <> " not found: " <> op, -1)
}

/// Delete a importedtrack by the `ByFilePath` identity.
pub fn delete_importedtrack_by_file_path(
  conn: sqlight.Connection,
  file_path file_path: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_importedtrack_by_file_path_sql,
      on: conn,
      with: [sqlight.int(now), sqlight.int(now), sqlight.text(file_path)],
      expecting: {
        use _n <- decode.field(0, decode.string)
        decode.success(Nil)
      },
    ),
  )
  case rows {
    [Nil, ..] -> Ok(Nil)
    [] ->
      Error(not_found_importedtrack_file_path_error(
        "delete_importedtrack_by_file_path",
      ))
  }
}

fn not_found_importedtrack_file_path_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}

/// Delete a importedtrack by the `ByTitleAndArtist` identity.
pub fn delete_importedtrack_by_title_and_artist(
  conn: sqlight.Connection,
  title title: String,
  artist artist: String,
) -> Result(Nil, sqlight.Error) {
  let now = api_help.unix_seconds_now()
  use rows <- result.try(
    sqlight.query(
      soft_delete_importedtrack_by_title_and_artist_sql,
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
    [] ->
      Error(not_found_importedtrack_title_and_artist_error(
        "delete_importedtrack_by_title_and_artist",
      ))
  }
}

fn not_found_importedtrack_title_and_artist_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}
