/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/api_help
import swil/cmd_runner

/// Upsert/update payload for `ByServiceAndSourceId` identity on `ImportedTrack`.
pub type ImportedTrackByServiceAndSourceId {
  ImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
}

pub type ImportedTrackCommand {
  /// Upsert by `ByServiceAndSourceId` identity.
  UpsertImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  /// Update by `ByServiceAndSourceId` identity.
  UpdateImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  /// Soft-delete by `ByServiceAndSourceId` identity.
  DeleteImportedTrackByServiceAndSourceId(service: String, source_id: String)
  /// Update all scalar columns by row `id`.
  UpdateImportedTrackById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
}

const importedtrack_upsert_by_service_and_source_id_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"service\", \"source_id\", \"added_to_library_at\", \"external_source_url\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, ?, ?, ?, null)
on conflict(\"service\", \"source_id\") do update set
  \"title\" = excluded.\"title\",
  \"artist\" = excluded.\"artist\",
  \"added_to_library_at\" = excluded.\"added_to_library_at\",
  \"external_source_url\" = excluded.\"external_source_url\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const importedtrack_update_by_service_and_source_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"added_to_library_at\" = ?, \"external_source_url\" = ?, \"updated_at\" = ? where \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"

const importedtrack_delete_by_service_and_source_id_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"

const importedtrack_update_by_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"service\" = ?, \"source_id\" = ?, \"added_to_library_at\" = ?, \"external_source_url\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

fn plan_importedtrack(
  cmd: ImportedTrackCommand,
  now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertImportedTrackByServiceAndSourceId(
      service:,
      source_id:,
      title:,
      artist:,
      added_to_library_at:,
      external_source_url:,
    ) -> #(importedtrack_upsert_by_service_and_source_id_sql, [
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
      sqlight.text(service),
      sqlight.text(source_id),
    ])
    DeleteImportedTrackByServiceAndSourceId(service:, source_id:) -> #(
      importedtrack_delete_by_service_and_source_id_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(service),
        sqlight.text(source_id),
      ],
    )
    UpdateImportedTrackById(
      id:,
      title:,
      artist:,
      service:,
      source_id:,
      added_to_library_at:,
      external_source_url:,
    ) -> #(importedtrack_update_by_id_sql, [
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

fn importedtrack_variant_tag(cmd: ImportedTrackCommand) -> Int {
  case cmd {
    UpsertImportedTrackByServiceAndSourceId(..) -> 0
    UpdateImportedTrackByServiceAndSourceId(..) -> 1
    DeleteImportedTrackByServiceAndSourceId(..) -> 2
    UpdateImportedTrackById(..) -> 3
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
