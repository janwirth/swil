/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
import case_studies/library_manager_db/row
import case_studies/library_manager_schema
import gleam/option
import sqlight
import swil/api_help
import swil/cmd_runner

/// Upsert/update payload for `ByTitleAndArtist` identity on `ImportedTrack`.
pub type ImportedTrackByTitleAndArtist {
  ImportedTrackByTitleAndArtist(
    title: String,
    artist: String,
    file_path: option.Option(String),
  )
}

/// Upsert/update payload for `ByFilePath` identity on `ImportedTrack`.
pub type ImportedTrackByFilePath {
  ImportedTrackByFilePath(
    file_path: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
}

pub type ImportedTrackCommand {
  /// Upsert by `ByTitleAndArtist` identity.
  UpsertImportedTrackByTitleAndArtist(
    title: String,
    artist: String,
    file_path: option.Option(String),
  )
  /// Update by `ByTitleAndArtist` identity.
  UpdateImportedTrackByTitleAndArtist(
    title: String,
    artist: String,
    file_path: option.Option(String),
  )
  /// Soft-delete by `ByTitleAndArtist` identity.
  DeleteImportedTrackByTitleAndArtist(title: String, artist: String)
  /// Upsert by `ByFilePath` identity.
  UpsertImportedTrackByFilePath(
    file_path: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
  /// Update by `ByFilePath` identity.
  UpdateImportedTrackByFilePath(
    file_path: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
  /// Soft-delete by `ByFilePath` identity.
  DeleteImportedTrackByFilePath(file_path: String)
  /// Update all scalar columns by row `id`.
  UpdateImportedTrackById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
    file_path: option.Option(String),
  )
}

/// Upsert/update payload for `ByTagLabel` identity on `Tag`.
pub type TagByTagLabel {
  TagByTagLabel(label: String, emoji: option.Option(String))
}

pub type TagCommand {
  /// Upsert by `ByTagLabel` identity.
  UpsertTagByTagLabel(label: String, emoji: option.Option(String))
  /// Update by `ByTagLabel` identity.
  UpdateTagByTagLabel(label: String, emoji: option.Option(String))
  /// Soft-delete by `ByTagLabel` identity.
  DeleteTagByTagLabel(label: String)
  /// Update all scalar columns by row `id`.
  UpdateTagById(
    id: Int,
    label: option.Option(String),
    emoji: option.Option(String),
  )
}

/// Upsert/update payload for `ByBucketTitleAndArtist` identity on `TrackBucket`.
pub type TrackBucketByBucketTitleAndArtist {
  TrackBucketByBucketTitleAndArtist(title: String, artist: String)
}

pub type TrackBucketCommand {
  /// Upsert by `ByBucketTitleAndArtist` identity.
  UpsertTrackBucketByBucketTitleAndArtist(title: String, artist: String)
  /// Update by `ByBucketTitleAndArtist` identity.
  UpdateTrackBucketByBucketTitleAndArtist(title: String, artist: String)
  /// Soft-delete by `ByBucketTitleAndArtist` identity.
  DeleteTrackBucketByBucketTitleAndArtist(title: String, artist: String)
  /// Update all scalar columns by row `id`.
  UpdateTrackBucketById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
  )
}

/// Upsert/update payload for `ByTabLabel` identity on `Tab`.
pub type TabByTabLabel {
  TabByTabLabel(
    label: String,
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
}

pub type TabCommand {
  /// Upsert by `ByTabLabel` identity.
  UpsertTabByTabLabel(
    label: String,
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
  /// Update by `ByTabLabel` identity.
  UpdateTabByTabLabel(
    label: String,
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
  /// Soft-delete by `ByTabLabel` identity.
  DeleteTabByTabLabel(label: String)
  /// Update all scalar columns by row `id`.
  UpdateTabById(
    id: Int,
    label: option.Option(String),
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
}

const importedtrack_upsert_by_title_and_artist_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"file_path\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"title\", \"artist\") do update set
  \"file_path\" = excluded.\"file_path\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const importedtrack_update_by_title_and_artist_sql = "update \"importedtrack\" set \"file_path\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const importedtrack_delete_by_title_and_artist_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const importedtrack_upsert_by_file_path_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"file_path\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"file_path\") do update set
  \"title\" = excluded.\"title\",
  \"artist\" = excluded.\"artist\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const importedtrack_update_by_file_path_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"updated_at\" = ? where \"file_path\" = ? and \"deleted_at\" is null;"

const importedtrack_delete_by_file_path_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"file_path\" = ? and \"deleted_at\" is null;"

const importedtrack_update_by_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"file_path\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

const tag_upsert_by_tag_label_sql = "insert into \"tag\" (\"label\", \"emoji\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"label\") do update set
  \"emoji\" = excluded.\"emoji\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const tag_update_by_tag_label_sql = "update \"tag\" set \"emoji\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null;"

const tag_delete_by_tag_label_sql = "update \"tag\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null;"

const tag_update_by_id_sql = "update \"tag\" set \"label\" = ?, \"emoji\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

const trackbucket_upsert_by_bucket_title_and_artist_sql = "insert into \"trackbucket\" (\"title\", \"artist\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"title\", \"artist\") do update set
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const trackbucket_update_by_bucket_title_and_artist_sql = "update \"trackbucket\" set \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const trackbucket_delete_by_bucket_title_and_artist_sql = "update \"trackbucket\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const trackbucket_update_by_id_sql = "update \"trackbucket\" set \"title\" = ?, \"artist\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

const tab_upsert_by_tab_label_sql = "insert into \"tab\" (\"label\", \"order\", \"view_config\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"label\") do update set
  \"order\" = excluded.\"order\",
  \"view_config\" = excluded.\"view_config\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const tab_update_by_tab_label_sql = "update \"tab\" set \"order\" = ?, \"view_config\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null;"

const tab_delete_by_tab_label_sql = "update \"tab\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null;"

const tab_update_by_id_sql = "update \"tab\" set \"label\" = ?, \"order\" = ?, \"view_config\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

fn plan_importedtrack(
  cmd: ImportedTrackCommand,
  now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertImportedTrackByTitleAndArtist(title:, artist:, file_path:) -> #(
      importedtrack_upsert_by_title_and_artist_sql,
      [
        sqlight.text(title),
        sqlight.text(artist),
        sqlight.text(api_help.opt_text_for_db(file_path)),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateImportedTrackByTitleAndArtist(title:, artist:, file_path:) -> #(
      importedtrack_update_by_title_and_artist_sql,
      [
        sqlight.text(api_help.opt_text_for_db(file_path)),
        sqlight.int(now),
        sqlight.text(title),
        sqlight.text(artist),
      ],
    )
    DeleteImportedTrackByTitleAndArtist(title:, artist:) -> #(
      importedtrack_delete_by_title_and_artist_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(title),
        sqlight.text(artist),
      ],
    )
    UpsertImportedTrackByFilePath(file_path:, title:, artist:) -> #(
      importedtrack_upsert_by_file_path_sql,
      [
        sqlight.text(api_help.opt_text_for_db(title)),
        sqlight.text(api_help.opt_text_for_db(artist)),
        sqlight.text(file_path),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateImportedTrackByFilePath(file_path:, title:, artist:) -> #(
      importedtrack_update_by_file_path_sql,
      [
        sqlight.text(api_help.opt_text_for_db(title)),
        sqlight.text(api_help.opt_text_for_db(artist)),
        sqlight.int(now),
        sqlight.text(file_path),
      ],
    )
    DeleteImportedTrackByFilePath(file_path:) -> #(
      importedtrack_delete_by_file_path_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(file_path),
      ],
    )
    UpdateImportedTrackById(id:, title:, artist:, file_path:) -> #(
      importedtrack_update_by_id_sql,
      [
        sqlight.text(api_help.opt_text_for_db(title)),
        sqlight.text(api_help.opt_text_for_db(artist)),
        sqlight.text(api_help.opt_text_for_db(file_path)),
        sqlight.int(now),
        sqlight.int(id),
      ],
    )
  }
}

fn plan_tag(cmd: TagCommand, now: Int) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertTagByTagLabel(label:, emoji:) -> #(tag_upsert_by_tag_label_sql, [
      sqlight.text(label),
      sqlight.text(api_help.opt_text_for_db(emoji)),
      sqlight.int(now),
      sqlight.int(now),
    ])
    UpdateTagByTagLabel(label:, emoji:) -> #(tag_update_by_tag_label_sql, [
      sqlight.text(api_help.opt_text_for_db(emoji)),
      sqlight.int(now),
      sqlight.text(label),
    ])
    DeleteTagByTagLabel(label:) -> #(tag_delete_by_tag_label_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(label),
    ])
    UpdateTagById(id:, label:, emoji:) -> #(tag_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(label)),
      sqlight.text(api_help.opt_text_for_db(emoji)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

fn plan_trackbucket(
  cmd: TrackBucketCommand,
  now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertTrackBucketByBucketTitleAndArtist(title:, artist:) -> #(
      trackbucket_upsert_by_bucket_title_and_artist_sql,
      [
        sqlight.text(title),
        sqlight.text(artist),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateTrackBucketByBucketTitleAndArtist(title:, artist:) -> #(
      trackbucket_update_by_bucket_title_and_artist_sql,
      [
        sqlight.int(now),
        sqlight.text(title),
        sqlight.text(artist),
      ],
    )
    DeleteTrackBucketByBucketTitleAndArtist(title:, artist:) -> #(
      trackbucket_delete_by_bucket_title_and_artist_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(title),
        sqlight.text(artist),
      ],
    )
    UpdateTrackBucketById(id:, title:, artist:) -> #(
      trackbucket_update_by_id_sql,
      [
        sqlight.text(api_help.opt_text_for_db(title)),
        sqlight.text(api_help.opt_text_for_db(artist)),
        sqlight.int(now),
        sqlight.int(id),
      ],
    )
  }
}

fn plan_tab(cmd: TabCommand, now: Int) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertTabByTabLabel(label:, order:, view_config:) -> #(
      tab_upsert_by_tab_label_sql,
      [
        sqlight.text(label),
        sqlight.float(api_help.opt_float_for_db(order)),
        sqlight.text(row.view_config_scalar_to_db_string(view_config)),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateTabByTabLabel(label:, order:, view_config:) -> #(
      tab_update_by_tab_label_sql,
      [
        sqlight.float(api_help.opt_float_for_db(order)),
        sqlight.text(row.view_config_scalar_to_db_string(view_config)),
        sqlight.int(now),
        sqlight.text(label),
      ],
    )
    DeleteTabByTabLabel(label:) -> #(tab_delete_by_tab_label_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(label),
    ])
    UpdateTabById(id:, label:, order:, view_config:) -> #(tab_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(label)),
      sqlight.float(api_help.opt_float_for_db(order)),
      sqlight.text(row.view_config_scalar_to_db_string(view_config)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

fn importedtrack_variant_tag(cmd: ImportedTrackCommand) -> Int {
  case cmd {
    UpsertImportedTrackByTitleAndArtist(..) -> 0
    UpdateImportedTrackByTitleAndArtist(..) -> 1
    DeleteImportedTrackByTitleAndArtist(..) -> 2
    UpsertImportedTrackByFilePath(..) -> 3
    UpdateImportedTrackByFilePath(..) -> 4
    DeleteImportedTrackByFilePath(..) -> 5
    UpdateImportedTrackById(..) -> 6
  }
}

fn tag_variant_tag(cmd: TagCommand) -> Int {
  case cmd {
    UpsertTagByTagLabel(..) -> 0
    UpdateTagByTagLabel(..) -> 1
    DeleteTagByTagLabel(..) -> 2
    UpdateTagById(..) -> 3
  }
}

fn trackbucket_variant_tag(cmd: TrackBucketCommand) -> Int {
  case cmd {
    UpsertTrackBucketByBucketTitleAndArtist(..) -> 0
    UpdateTrackBucketByBucketTitleAndArtist(..) -> 1
    DeleteTrackBucketByBucketTitleAndArtist(..) -> 2
    UpdateTrackBucketById(..) -> 3
  }
}

fn tab_variant_tag(cmd: TabCommand) -> Int {
  case cmd {
    UpsertTabByTabLabel(..) -> 0
    UpdateTabByTabLabel(..) -> 1
    DeleteTabByTabLabel(..) -> 2
    UpdateTabById(..) -> 3
  }
}

pub fn execute_importedtrack_cmds(
  conn: sqlight.Connection,
  commands: List(ImportedTrackCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(
    conn,
    commands,
    importedtrack_variant_tag,
    plan_importedtrack,
  )
}

pub fn execute_tag_cmds(
  conn: sqlight.Connection,
  commands: List(TagCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, tag_variant_tag, plan_tag)
}

pub fn execute_trackbucket_cmds(
  conn: sqlight.Connection,
  commands: List(TrackBucketCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, trackbucket_variant_tag, plan_trackbucket)
}

pub fn execute_tab_cmds(
  conn: sqlight.Connection,
  commands: List(TabCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, tab_variant_tag, plan_tab)
}
