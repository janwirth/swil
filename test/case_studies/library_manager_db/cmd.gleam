import case_studies/library_manager_db/row
import case_studies/library_manager_schema
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import sqlight
import swil/runtime/api_help
import swil/runtime/cmd_runner

pub type TabCommand {
  UpsertTabByTabLabel(
    label: String,
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
  UpdateTabByTabLabel(
    label: String,
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
  PatchTabByTabLabel(
    label: String,
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
  DeleteTabByTabLabel(label: String)
  UpdateTabById(
    id: Int,
    label: option.Option(String),
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
  PatchTabById(
    id: Int,
    label: option.Option(String),
    order: option.Option(Float),
    view_config: option.Option(library_manager_schema.ViewConfigScalar),
  )
}

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

pub fn execute_tab_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(TabCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, tab_variant_tag, plan_tab)
}

fn tab_variant_tag(cmd cmd: TabCommand) -> Int {
  case cmd {
    UpsertTabByTabLabel(..) -> 0
    UpdateTabByTabLabel(..) -> 1
    PatchTabByTabLabel(..) -> 2
    DeleteTabByTabLabel(..) -> 3
    PatchTabById(..) -> 4
    UpdateTabById(..) -> 5
  }
}

fn plan_tab(cmd cmd: TabCommand, now now: Int) -> #(String, List(sqlight.Value)) {
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
    PatchTabByTabLabel(label:, order:, view_config:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case order {
        option.None -> #(set_parts, binds)
        option.Some(order_pv) -> #(["\"order\" = ?", ..set_parts], [
          sqlight.float(order_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case view_config {
        option.None -> #(set_parts, binds)
        option.Some(view_config_pv) -> #(["\"view_config\" = ?", ..set_parts], [
          sqlight.text(
            row.view_config_scalar_to_db_string(option.Some(view_config_pv)),
          ),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"tab\" set "
        <> set_sql
        <> " where \"label\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(label),
          ],
        ])
      #(sql, binds)
    }
    DeleteTabByTabLabel(label:) -> #(tab_delete_by_tab_label_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(label),
    ])
    PatchTabById(id:, label:, order:, view_config:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case label {
        option.None -> #(set_parts, binds)
        option.Some(label_pv) -> #(["\"label\" = ?", ..set_parts], [
          sqlight.text(label_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case order {
        option.None -> #(set_parts, binds)
        option.Some(order_pv) -> #(["\"order\" = ?", ..set_parts], [
          sqlight.float(order_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case view_config {
        option.None -> #(set_parts, binds)
        option.Some(view_config_pv) -> #(["\"view_config\" = ?", ..set_parts], [
          sqlight.text(
            row.view_config_scalar_to_db_string(option.Some(view_config_pv)),
          ),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"tab\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
    UpdateTabById(id:, label:, order:, view_config:) -> #(tab_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(label)),
      sqlight.float(api_help.opt_float_for_db(order)),
      sqlight.text(row.view_config_scalar_to_db_string(view_config)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

pub type TrackBucketCommand {
  UpsertTrackBucketByBucketTitleAndArtist(title: String, artist: String)
  UpdateTrackBucketByBucketTitleAndArtist(title: String, artist: String)
  PatchTrackBucketByBucketTitleAndArtist(title: String, artist: String)
  DeleteTrackBucketByBucketTitleAndArtist(title: String, artist: String)
  UpdateTrackBucketById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
  )
  PatchTrackBucketById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
  )
}

const trackbucket_upsert_by_bucket_title_and_artist_sql = "insert into \"trackbucket\" (\"title\", \"artist\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"title\", \"artist\") do update set
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const trackbucket_update_by_bucket_title_and_artist_sql = "update \"trackbucket\" set \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const trackbucket_delete_by_bucket_title_and_artist_sql = "update \"trackbucket\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const trackbucket_update_by_id_sql = "update \"trackbucket\" set \"title\" = ?, \"artist\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_trackbucket_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(TrackBucketCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, trackbucket_variant_tag, plan_trackbucket)
}

fn trackbucket_variant_tag(cmd cmd: TrackBucketCommand) -> Int {
  case cmd {
    UpsertTrackBucketByBucketTitleAndArtist(..) -> 0
    UpdateTrackBucketByBucketTitleAndArtist(..) -> 1
    PatchTrackBucketByBucketTitleAndArtist(..) -> 2
    DeleteTrackBucketByBucketTitleAndArtist(..) -> 3
    PatchTrackBucketById(..) -> 4
    UpdateTrackBucketById(..) -> 5
  }
}

fn plan_trackbucket(
  cmd cmd: TrackBucketCommand,
  now now: Int,
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
    PatchTrackBucketByBucketTitleAndArtist(title:, artist:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"trackbucket\" set "
        <> set_sql
        <> " where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(title),
            sqlight.text(artist),
          ],
        ])
      #(sql, binds)
    }
    DeleteTrackBucketByBucketTitleAndArtist(title:, artist:) -> #(
      trackbucket_delete_by_bucket_title_and_artist_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(title),
        sqlight.text(artist),
      ],
    )
    PatchTrackBucketById(id:, title:, artist:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case title {
        option.None -> #(set_parts, binds)
        option.Some(title_pv) -> #(["\"title\" = ?", ..set_parts], [
          sqlight.text(title_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case artist {
        option.None -> #(set_parts, binds)
        option.Some(artist_pv) -> #(["\"artist\" = ?", ..set_parts], [
          sqlight.text(artist_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"trackbucket\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
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

pub type TagCommand {
  UpsertTagByTagLabel(label: String, emoji: option.Option(String))
  UpdateTagByTagLabel(label: String, emoji: option.Option(String))
  PatchTagByTagLabel(label: String, emoji: option.Option(String))
  DeleteTagByTagLabel(label: String)
  UpdateTagById(
    id: Int,
    label: option.Option(String),
    emoji: option.Option(String),
  )
  PatchTagById(
    id: Int,
    label: option.Option(String),
    emoji: option.Option(String),
  )
}

const tag_upsert_by_tag_label_sql = "insert into \"tag\" (\"label\", \"emoji\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"label\") do update set
  \"emoji\" = excluded.\"emoji\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const tag_update_by_tag_label_sql = "update \"tag\" set \"emoji\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null;"

const tag_delete_by_tag_label_sql = "update \"tag\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null;"

const tag_update_by_id_sql = "update \"tag\" set \"label\" = ?, \"emoji\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_tag_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(TagCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, tag_variant_tag, plan_tag)
}

fn tag_variant_tag(cmd cmd: TagCommand) -> Int {
  case cmd {
    UpsertTagByTagLabel(..) -> 0
    UpdateTagByTagLabel(..) -> 1
    PatchTagByTagLabel(..) -> 2
    DeleteTagByTagLabel(..) -> 3
    PatchTagById(..) -> 4
    UpdateTagById(..) -> 5
  }
}

fn plan_tag(cmd cmd: TagCommand, now now: Int) -> #(String, List(sqlight.Value)) {
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
    PatchTagByTagLabel(label:, emoji:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case emoji {
        option.None -> #(set_parts, binds)
        option.Some(emoji_pv) -> #(["\"emoji\" = ?", ..set_parts], [
          sqlight.text(emoji_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"tag\" set "
        <> set_sql
        <> " where \"label\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(label),
          ],
        ])
      #(sql, binds)
    }
    DeleteTagByTagLabel(label:) -> #(tag_delete_by_tag_label_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(label),
    ])
    PatchTagById(id:, label:, emoji:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case label {
        option.None -> #(set_parts, binds)
        option.Some(label_pv) -> #(["\"label\" = ?", ..set_parts], [
          sqlight.text(label_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case emoji {
        option.None -> #(set_parts, binds)
        option.Some(emoji_pv) -> #(["\"emoji\" = ?", ..set_parts], [
          sqlight.text(emoji_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"tag\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
    UpdateTagById(id:, label:, emoji:) -> #(tag_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(label)),
      sqlight.text(api_help.opt_text_for_db(emoji)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/runtime/cmd_runner` for batching.
pub type ImportedTrackCommand {
  UpsertImportedTrackByTitleAndArtist(
    title: String,
    artist: String,
    file_path: option.Option(String),
  )
  UpdateImportedTrackByTitleAndArtist(
    title: String,
    artist: String,
    file_path: option.Option(String),
  )
  PatchImportedTrackByTitleAndArtist(
    title: String,
    artist: String,
    file_path: option.Option(String),
  )
  DeleteImportedTrackByTitleAndArtist(title: String, artist: String)
  UpsertImportedTrackByFilePath(
    file_path: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
  UpdateImportedTrackByFilePath(
    file_path: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
  PatchImportedTrackByFilePath(
    file_path: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
  DeleteImportedTrackByFilePath(file_path: String)
  UpdateImportedTrackById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
    file_path: option.Option(String),
  )
  PatchImportedTrackById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
    file_path: option.Option(String),
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

pub fn execute_importedtrack_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(ImportedTrackCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(
    conn,
    commands,
    importedtrack_variant_tag,
    plan_importedtrack,
  )
}

fn importedtrack_variant_tag(cmd cmd: ImportedTrackCommand) -> Int {
  case cmd {
    UpsertImportedTrackByTitleAndArtist(..) -> 0
    UpdateImportedTrackByTitleAndArtist(..) -> 1
    PatchImportedTrackByTitleAndArtist(..) -> 2
    DeleteImportedTrackByTitleAndArtist(..) -> 3
    UpsertImportedTrackByFilePath(..) -> 4
    UpdateImportedTrackByFilePath(..) -> 5
    PatchImportedTrackByFilePath(..) -> 6
    DeleteImportedTrackByFilePath(..) -> 7
    PatchImportedTrackById(..) -> 8
    UpdateImportedTrackById(..) -> 9
  }
}

fn plan_importedtrack(
  cmd cmd: ImportedTrackCommand,
  now now: Int,
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
    PatchImportedTrackByTitleAndArtist(title:, artist:, file_path:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case file_path {
        option.None -> #(set_parts, binds)
        option.Some(file_path_pv) -> #(["\"file_path\" = ?", ..set_parts], [
          sqlight.text(file_path_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"importedtrack\" set "
        <> set_sql
        <> " where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(title),
            sqlight.text(artist),
          ],
        ])
      #(sql, binds)
    }
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
    PatchImportedTrackByFilePath(file_path:, title:, artist:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case title {
        option.None -> #(set_parts, binds)
        option.Some(title_pv) -> #(["\"title\" = ?", ..set_parts], [
          sqlight.text(title_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case artist {
        option.None -> #(set_parts, binds)
        option.Some(artist_pv) -> #(["\"artist\" = ?", ..set_parts], [
          sqlight.text(artist_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"importedtrack\" set "
        <> set_sql
        <> " where \"file_path\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(file_path),
          ],
        ])
      #(sql, binds)
    }
    DeleteImportedTrackByFilePath(file_path:) -> #(
      importedtrack_delete_by_file_path_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(file_path),
      ],
    )
    PatchImportedTrackById(id:, title:, artist:, file_path:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case title {
        option.None -> #(set_parts, binds)
        option.Some(title_pv) -> #(["\"title\" = ?", ..set_parts], [
          sqlight.text(title_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case artist {
        option.None -> #(set_parts, binds)
        option.Some(artist_pv) -> #(["\"artist\" = ?", ..set_parts], [
          sqlight.text(artist_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case file_path {
        option.None -> #(set_parts, binds)
        option.Some(file_path_pv) -> #(["\"file_path\" = ?", ..set_parts], [
          sqlight.text(file_path_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"importedtrack\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
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

const upsert_trackbucket_tag_sql = "insert into \"trackbucket_tag\" (\"trackbucket_id\", \"tag_id\", \"value\") values (?, ?, ?) on conflict (\"trackbucket_id\", \"tag_id\") do update set \"value\" = excluded.\"value\";"

pub fn upsert_trackbucket_tag(
  conn: sqlight.Connection,
  trackbucket_id trackbucket_id: Int,
  tag_id tag_id: Int,
  value value: option.Option(Int),
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    upsert_trackbucket_tag_sql,
    on: conn,
    with: [
      sqlight.int(trackbucket_id),
      sqlight.int(tag_id),
      case value {
        option.Some(v) -> sqlight.int(v)
        option.None -> sqlight.null()
      },
    ],
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_) { Nil })
}
