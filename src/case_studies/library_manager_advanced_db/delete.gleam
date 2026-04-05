import case_studies/library_manager_advanced_db/cmd
import case_studies/library_manager_advanced_db/get
import gleam/option
import gleam/result
import sqlight

/// Delete a tab by the `ByTabLabel` identity.
pub fn delete_tab_by_tab_label(
  conn: sqlight.Connection,
  label label: String,
) -> Result(Nil, sqlight.Error) {
  use existing <- result.try(get.get_tab_by_tab_label(conn, label: label))
  case existing {
    option.None ->
      Error(not_found_tab_tab_label_error("delete_tab_by_tab_label"))
    option.Some(_) -> {
      case cmd.execute_tab_cmds(conn, [cmd.DeleteTabByTabLabel(label: label)]) {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
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
  use existing <- result.try(get.get_trackbucket_by_bucket_title_and_artist(
    conn,
    title: title,
    artist: artist,
  ))
  case existing {
    option.None ->
      Error(not_found_trackbucket_bucket_title_and_artist_error(
        "delete_trackbucket_by_bucket_title_and_artist",
      ))
    option.Some(_) -> {
      case
        cmd.execute_trackbucket_cmds(conn, [
          cmd.DeleteTrackBucketByBucketTitleAndArtist(
            title: title,
            artist: artist,
          ),
        ])
      {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
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
  use existing <- result.try(get.get_tag_by_tag_label(conn, label: label))
  case existing {
    option.None ->
      Error(not_found_tag_tag_label_error("delete_tag_by_tag_label"))
    option.Some(_) -> {
      case cmd.execute_tag_cmds(conn, [cmd.DeleteTagByTagLabel(label: label)]) {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
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
  use existing <- result.try(get.get_importedtrack_by_file_path(
    conn,
    file_path: file_path,
  ))
  case existing {
    option.None ->
      Error(not_found_importedtrack_file_path_error(
        "delete_importedtrack_by_file_path",
      ))
    option.Some(_) -> {
      case
        cmd.execute_importedtrack_cmds(conn, [
          cmd.DeleteImportedTrackByFilePath(file_path: file_path),
        ])
      {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
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
  use existing <- result.try(get.get_importedtrack_by_title_and_artist(
    conn,
    title: title,
    artist: artist,
  ))
  case existing {
    option.None ->
      Error(not_found_importedtrack_title_and_artist_error(
        "delete_importedtrack_by_title_and_artist",
      ))
    option.Some(_) -> {
      case
        cmd.execute_importedtrack_cmds(conn, [
          cmd.DeleteImportedTrackByTitleAndArtist(title: title, artist: artist),
        ])
      {
        Ok(Nil) -> Ok(Nil)
        Error(#(_, e)) -> Error(e)
      }
    }
  }
}

fn not_found_importedtrack_title_and_artist_error(op: String) -> sqlight.Error {
  sqlight.SqlightError(
    sqlight.GenericError,
    "importedtrack" <> " not found: " <> op,
    -1,
  )
}
