/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
import gleam/list
import gleam/option
import gleam/string
import sqlight
import swil/api_help
import swil/cmd_runner

pub type ImportedTrackCommand {
  /// Upsert by `ByServiceAndSourceId` identity.
  UpsertImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
  /// Update by `ByServiceAndSourceId` identity (every non-id column is written; `option.None` uses sentinel / empty DB encoding).
  UpdateImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
  /// Partial update by `ByServiceAndSourceId` (`option.None` leaves that column unchanged in SQL).
  PatchImportedTrackByServiceAndSourceId(
    service: String,
    source_id: String,
    title: option.Option(String),
    artist: option.Option(String),
  )
  /// Soft-delete by `ByServiceAndSourceId` identity.
  DeleteImportedTrackByServiceAndSourceId(service: String, source_id: String)
  /// Update all scalar columns by row `id` (same sentinel rules as identity `Update`).
  UpdateImportedTrackById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
  )
  /// Partial update by row `id` (`option.None` leaves that column unchanged).
  PatchImportedTrackById(
    id: Int,
    title: option.Option(String),
    artist: option.Option(String),
    service: option.Option(String),
    source_id: option.Option(String),
  )
}

const importedtrack_upsert_by_service_and_source_id_sql = "insert into \"importedtrack\" (\"title\", \"artist\", \"service\", \"source_id\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, ?, null)
on conflict(\"service\", \"source_id\") do update set
  \"title\" = excluded.\"title\",
  \"artist\" = excluded.\"artist\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const importedtrack_update_by_service_and_source_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"updated_at\" = ? where \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"

const importedtrack_delete_by_service_and_source_id_sql = "update \"importedtrack\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"

const importedtrack_update_by_id_sql = "update \"importedtrack\" set \"title\" = ?, \"artist\" = ?, \"service\" = ?, \"source_id\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

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
    ) -> #(importedtrack_upsert_by_service_and_source_id_sql, [
      sqlight.text(api_help.opt_text_for_db(title)),
      sqlight.text(api_help.opt_text_for_db(artist)),
      sqlight.text(service),
      sqlight.text(source_id),
      sqlight.int(now),
      sqlight.int(now),
    ])
    UpdateImportedTrackByServiceAndSourceId(
      service:,
      source_id:,
      title:,
      artist:,
    ) -> #(importedtrack_update_by_service_and_source_id_sql, [
      sqlight.text(api_help.opt_text_for_db(title)),
      sqlight.text(api_help.opt_text_for_db(artist)),
      sqlight.int(now),
      sqlight.text(service),
      sqlight.text(source_id),
    ])
    PatchImportedTrackByServiceAndSourceId(
      service:,
      source_id:,
      title:,
      artist:,
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
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"importedtrack\" set "
        <> set_sql
        <> " where \"service\" = ? and \"source_id\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(service),
            sqlight.text(source_id),
          ],
        ])
      #(sql, binds)
    }
    DeleteImportedTrackByServiceAndSourceId(service:, source_id:) -> #(
      importedtrack_delete_by_service_and_source_id_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(service),
        sqlight.text(source_id),
      ],
    )
    PatchImportedTrackById(id:, title:, artist:, service:, source_id:) -> {
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
    UpdateImportedTrackById(id:, title:, artist:, service:, source_id:) -> #(
      importedtrack_update_by_id_sql,
      [
        sqlight.text(api_help.opt_text_for_db(title)),
        sqlight.text(api_help.opt_text_for_db(artist)),
        sqlight.text(api_help.opt_text_for_db(service)),
        sqlight.text(api_help.opt_text_for_db(source_id)),
        sqlight.int(now),
        sqlight.int(id),
      ],
    )
  }
}

fn importedtrack_variant_tag(cmd: ImportedTrackCommand) -> Int {
  case cmd {
    UpsertImportedTrackByServiceAndSourceId(..) -> 0
    UpdateImportedTrackByServiceAndSourceId(..) -> 1
    PatchImportedTrackByServiceAndSourceId(..) -> 2
    DeleteImportedTrackByServiceAndSourceId(..) -> 3
    PatchImportedTrackById(..) -> 4
    UpdateImportedTrackById(..) -> 5
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
