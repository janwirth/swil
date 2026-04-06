import gleam/option
import gleam/time/timestamp.{type Timestamp}
import sqlight
import swil/runtime/api_help
import swil/runtime/cmd_runner
import swil/runtime/patch

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/runtime/cmd_runner` for batching.
pub type ImportedTrackCommand {
  UpsertImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  UpdateImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  PatchImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  DeleteImportedTrackByServiceAndSourceId(service: String, source_id: String)
  UpdateImportedTrackById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
    added_to_library_at: option.Option(Timestamp),
    external_source_url: option.Option(String),
  )
  PatchImportedTrackById(
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
    PatchImportedTrackByServiceAndSourceId(
      service:,
      source_id:,
      title:,
      artist:,
      added_to_library_at:,
      external_source_url:,
    ) ->
      patch.new()
      |> patch.add_text("title", title)
      |> patch.add_text("artist", artist)
      |> patch.add_int(
        "added_to_library_at",
        option.map(added_to_library_at, fn(t) {
          let #(s, _) = timestamp.to_unix_seconds_and_nanoseconds(t)
          s
        }),
      )
      |> patch.add_text("external_source_url", external_source_url)
      |> patch.always_int("updated_at", now)
      |> patch.build(
        "importedtrack",
        "\"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;",
        [sqlight.text(service), sqlight.text(source_id)],
      )
    DeleteImportedTrackByServiceAndSourceId(service:, source_id:) -> #(
      importedtrack_delete_by_service_and_source_id_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(service),
        sqlight.text(source_id),
      ],
    )
    PatchImportedTrackById(
      id:,
      title:,
      artist:,
      service:,
      source_id:,
      added_to_library_at:,
      external_source_url:,
    ) ->
      patch.new()
      |> patch.add_text("title", title)
      |> patch.add_text("artist", artist)
      |> patch.add_text("service", service)
      |> patch.add_text("source_id", source_id)
      |> patch.add_int(
        "added_to_library_at",
        option.map(added_to_library_at, fn(t) {
          let #(s, _) = timestamp.to_unix_seconds_and_nanoseconds(t)
          s
        }),
      )
      |> patch.add_text("external_source_url", external_source_url)
      |> patch.always_int("updated_at", now)
      |> patch.build("importedtrack", "\"id\" = ? and \"deleted_at\" is null;", [
        sqlight.int(id),
      ])
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
