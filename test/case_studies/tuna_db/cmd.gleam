import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/runtime/api_help
import swil/runtime/cmd_runner

pub type TagCommand {
  UpsertTagByLabel(label: String)
  UpdateTagByLabel(label: String)
  PatchTagByLabel(label: String)
  DeleteTagByLabel(label: String)
  UpdateTagById(id: Int, label: option.Option(String))
  PatchTagById(id: Int, label: option.Option(String))
}

const tag_upsert_by_label_sql = "insert into \"tag\" (\"label\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, null)
on conflict(\"label\") do update set
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const tag_update_by_label_sql = "update \"tag\" set \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null;"

const tag_delete_by_label_sql = "update \"tag\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"label\" = ? and \"deleted_at\" is null;"

const tag_update_by_id_sql = "update \"tag\" set \"label\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_tag_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(TagCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, tag_variant_tag, plan_tag)
}

fn tag_variant_tag(cmd cmd: TagCommand) -> Int {
  case cmd {
    UpsertTagByLabel(..) -> 0
    UpdateTagByLabel(..) -> 1
    PatchTagByLabel(..) -> 2
    DeleteTagByLabel(..) -> 3
    PatchTagById(..) -> 4
    UpdateTagById(..) -> 5
  }
}

fn plan_tag(cmd cmd: TagCommand, now now: Int) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertTagByLabel(label:) -> #(tag_upsert_by_label_sql, [
      sqlight.text(label),
      sqlight.int(now),
      sqlight.int(now),
    ])
    UpdateTagByLabel(label:) -> #(tag_update_by_label_sql, [
      sqlight.int(now),
      sqlight.text(label),
    ])
    PatchTagByLabel(label:) -> {
      let #(set_parts, binds) = #([], [])
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
    DeleteTagByLabel(label:) -> #(tag_delete_by_label_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(label),
    ])
    PatchTagById(id:, label:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case label {
        option.None -> #(set_parts, binds)
        option.Some(label_pv) -> #(["\"label\" = ?", ..set_parts], [
          sqlight.text(label_pv),
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
    UpdateTagById(id:, label:) -> #(tag_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(label)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

pub type TrackBucketCommand {
  UpsertTrackBucketByTitleAndArtist(title: String, artist: String)
  UpdateTrackBucketByTitleAndArtist(title: String, artist: String)
  PatchTrackBucketByTitleAndArtist(title: String, artist: String)
  DeleteTrackBucketByTitleAndArtist(title: String, artist: String)
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

const trackbucket_upsert_by_title_and_artist_sql = "insert into \"trackbucket\" (\"title\", \"artist\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"title\", \"artist\") do update set
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const trackbucket_update_by_title_and_artist_sql = "update \"trackbucket\" set \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const trackbucket_delete_by_title_and_artist_sql = "update \"trackbucket\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"title\" = ? and \"artist\" = ? and \"deleted_at\" is null;"

const trackbucket_update_by_id_sql = "update \"trackbucket\" set \"title\" = ?, \"artist\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_trackbucket_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(TrackBucketCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, trackbucket_variant_tag, plan_trackbucket)
}

fn trackbucket_variant_tag(cmd cmd: TrackBucketCommand) -> Int {
  case cmd {
    UpsertTrackBucketByTitleAndArtist(..) -> 0
    UpdateTrackBucketByTitleAndArtist(..) -> 1
    PatchTrackBucketByTitleAndArtist(..) -> 2
    DeleteTrackBucketByTitleAndArtist(..) -> 3
    PatchTrackBucketById(..) -> 4
    UpdateTrackBucketById(..) -> 5
  }
}

fn plan_trackbucket(
  cmd cmd: TrackBucketCommand,
  now now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertTrackBucketByTitleAndArtist(title:, artist:) -> #(
      trackbucket_upsert_by_title_and_artist_sql,
      [
        sqlight.text(title),
        sqlight.text(artist),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateTrackBucketByTitleAndArtist(title:, artist:) -> #(
      trackbucket_update_by_title_and_artist_sql,
      [
        sqlight.int(now),
        sqlight.text(title),
        sqlight.text(artist),
      ],
    )
    PatchTrackBucketByTitleAndArtist(title:, artist:) -> {
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
    DeleteTrackBucketByTitleAndArtist(title:, artist:) -> #(
      trackbucket_delete_by_title_and_artist_sql,
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

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/runtime/cmd_runner` for batching.
pub type ImportedTrackCommand {
  UpsertImportedTrackByServiceAndSourceId(
    from_source_root: String,
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  UpdateImportedTrackByServiceAndSourceId(
    from_source_root: String,
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  PatchImportedTrackByServiceAndSourceId(
    from_source_root: String,
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  DeleteImportedTrackByServiceAndSourceId(
    from_source_root: String,
    service: String,
    source_id: String,
  )
  UpdateImportedTrackById(
    id: Int,
    from_source_root: option.Option(String),
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  PatchImportedTrackById(
    id: Int,
    from_source_root: option.Option(String),
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
}

const importedtrack_upsert_by_service_and_source_id_sql = "insert into \"importedtrack\" (\"from_source_root\", \"title\", \"artist\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, ?, ?, ?, ?, null)
on conflict(\"from_source_root\", \"service\", \"source_id\") do update set
  \"title\" = excluded.\"title\",
  \"artist\" = excluded.\"artist\",
  \"added_to_library_at\" = excluded.\"added_to_library_at\",
  \"external_source_url\" = excluded.\"external_source_url\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const importedtrack_update_by_service_and_source_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"added_to_library_at\" = ?, \"external_source_url\" = ?, \"updated_at\" = ? where \"from_source_root\" = ? and \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"

const importedtrack_delete_by_service_and_source_id_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"from_source_root\" = ? and \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"

const importedtrack_update_by_id_sql = "update \"importedtrack\" set \"from_source_root\" = ?, \"title\" = ?, \"artist\" = ?, \"service\" = ?, \"source_id\" = ?, \"added_to_library_at\" = ?, \"external_source_url\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

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
    UpsertImportedTrackByServiceAndSourceId(..) -> 0
    UpdateImportedTrackByServiceAndSourceId(..) -> 1
    PatchImportedTrackByServiceAndSourceId(..) -> 2
    DeleteImportedTrackByServiceAndSourceId(..) -> 3
    PatchImportedTrackById(..) -> 4
    UpdateImportedTrackById(..) -> 5
  }
}

fn plan_importedtrack(
  cmd cmd: ImportedTrackCommand,
  now now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertImportedTrackByServiceAndSourceId(
      from_source_root:,
      service:,
      source_id:,
      title:,
      artist:,
      added_to_library_at:,
      external_source_url:,
    ) -> #(importedtrack_upsert_by_service_and_source_id_sql, [
      sqlight.text(from_source_root),
      sqlight.text(api_help.opt_text_for_db(title)),
      sqlight.text(api_help.opt_text_for_db(artist)),
      sqlight.text(service),
      sqlight.text(source_id),
      sqlight.int(api_help.opt_timestamp_for_db(added_to_library_at)),
      sqlight.text(api_help.opt_text_for_db(external_source_url)),
      sqlight.int(now),
      sqlight.int(now),
    ])
    UpdateImportedTrackByServiceAndSourceId(
      from_source_root:,
      service:,
      source_id:,
      title:,
      artist:,
      added_to_library_at:,
      external_source_url:,
    ) -> #(importedtrack_update_by_service_and_source_id_sql, [
      sqlight.text(api_help.opt_text_for_db(title)),
      sqlight.text(api_help.opt_text_for_db(artist)),
      sqlight.int(api_help.opt_timestamp_for_db(added_to_library_at)),
      sqlight.text(api_help.opt_text_for_db(external_source_url)),
      sqlight.int(now),
      sqlight.text(from_source_root),
      sqlight.text(service),
      sqlight.text(source_id),
    ])
    PatchImportedTrackByServiceAndSourceId(
      from_source_root:,
      service:,
      source_id:,
      title:,
      artist:,
      added_to_library_at:,
      external_source_url:,
    ) -> {
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
      let #(set_parts, binds) = case added_to_library_at {
        option.None -> #(set_parts, binds)
        option.Some(added_to_library_at_pv) -> #(
          ["\"added_to_library_at\" = ?", ..set_parts],
          [
            sqlight.int({
              let #(s, _) =
                timestamp.to_unix_seconds_and_nanoseconds(
                  added_to_library_at_pv,
                )
              s
            }),
            ..binds
          ],
        )
      }
      let #(set_parts, binds) = case external_source_url {
        option.None -> #(set_parts, binds)
        option.Some(external_source_url_pv) -> #(
          ["\"external_source_url\" = ?", ..set_parts],
          [sqlight.text(external_source_url_pv), ..binds],
        )
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"importedtrack\" set "
        <> set_sql
        <> " where \"from_source_root\" = ? and \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(from_source_root),
            sqlight.text(service),
            sqlight.text(source_id),
          ],
        ])
      #(sql, binds)
    }
    DeleteImportedTrackByServiceAndSourceId(
      from_source_root:,
      service:,
      source_id:,
    ) -> #(importedtrack_delete_by_service_and_source_id_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(from_source_root),
      sqlight.text(service),
      sqlight.text(source_id),
    ])
    PatchImportedTrackById(
      id:,
      from_source_root:,
      title:,
      artist:,
      service:,
      source_id:,
      added_to_library_at:,
      external_source_url:,
    ) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case from_source_root {
        option.None -> #(set_parts, binds)
        option.Some(from_source_root_pv) -> #(
          ["\"from_source_root\" = ?", ..set_parts],
          [sqlight.text(from_source_root_pv), ..binds],
        )
      }
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
      let #(set_parts, binds) = case service {
        option.None -> #(set_parts, binds)
        option.Some(service_pv) -> #(["\"service\" = ?", ..set_parts], [
          sqlight.text(service_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case source_id {
        option.None -> #(set_parts, binds)
        option.Some(source_id_pv) -> #(["\"source_id\" = ?", ..set_parts], [
          sqlight.text(source_id_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case added_to_library_at {
        option.None -> #(set_parts, binds)
        option.Some(added_to_library_at_pv) -> #(
          ["\"added_to_library_at\" = ?", ..set_parts],
          [
            sqlight.int({
              let #(s, _) =
                timestamp.to_unix_seconds_and_nanoseconds(
                  added_to_library_at_pv,
                )
              s
            }),
            ..binds
          ],
        )
      }
      let #(set_parts, binds) = case external_source_url {
        option.None -> #(set_parts, binds)
        option.Some(external_source_url_pv) -> #(
          ["\"external_source_url\" = ?", ..set_parts],
          [sqlight.text(external_source_url_pv), ..binds],
        )
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
    UpdateImportedTrackById(
      id:,
      from_source_root:,
      title:,
      artist:,
      service:,
      source_id:,
      added_to_library_at:,
      external_source_url:,
    ) -> #(importedtrack_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(from_source_root)),
      sqlight.text(api_help.opt_text_for_db(title)),
      sqlight.text(api_help.opt_text_for_db(artist)),
      sqlight.text(api_help.opt_text_for_db(service)),
      sqlight.text(api_help.opt_text_for_db(source_id)),
      sqlight.int(api_help.opt_timestamp_for_db(added_to_library_at)),
      sqlight.text(api_help.opt_text_for_db(external_source_url)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}
