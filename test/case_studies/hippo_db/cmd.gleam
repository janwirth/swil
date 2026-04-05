import case_studies/hippo_db/row
import case_studies/hippo_schema
import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import sqlight
import swil/api_help
import swil/cmd_runner

pub type HumanCommand {
  UpsertHumanByEmail(email: String, name: option.Option(String))
  UpdateHumanByEmail(email: String, name: option.Option(String))
  PatchHumanByEmail(email: String, name: option.Option(String))
  DeleteHumanByEmail(email: String)
  UpdateHumanById(
    id: Int,
    name: option.Option(String),
    email: option.Option(String),
  )
  PatchHumanById(
    id: Int,
    name: option.Option(String),
    email: option.Option(String),
  )
}

const human_upsert_by_email_sql = "insert into \"human\" (\"name\", \"email\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"email\") do update set
  \"name\" = excluded.\"name\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const human_update_by_email_sql = "update \"human\" set \"name\" = ?, \"updated_at\" = ? where \"email\" = ? and \"deleted_at\" is null;"

const human_delete_by_email_sql = "update \"human\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"email\" = ? and \"deleted_at\" is null;"

const human_update_by_id_sql = "update \"human\" set \"name\" = ?, \"email\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_human_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(HumanCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, human_variant_tag, plan_human)
}

fn human_variant_tag(cmd cmd: HumanCommand) -> Int {
  case cmd {
    UpsertHumanByEmail(..) -> 0
    UpdateHumanByEmail(..) -> 1
    PatchHumanByEmail(..) -> 2
    DeleteHumanByEmail(..) -> 3
    PatchHumanById(..) -> 4
    UpdateHumanById(..) -> 5
  }
}

fn plan_human(
  cmd cmd: HumanCommand,
  now now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertHumanByEmail(email:, name:) -> #(human_upsert_by_email_sql, [
      sqlight.text(api_help.opt_text_for_db(name)),
      sqlight.text(email),
      sqlight.int(now),
      sqlight.int(now),
    ])
    UpdateHumanByEmail(email:, name:) -> #(human_update_by_email_sql, [
      sqlight.text(api_help.opt_text_for_db(name)),
      sqlight.int(now),
      sqlight.text(email),
    ])
    PatchHumanByEmail(email:, name:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case name {
        option.None -> #(set_parts, binds)
        option.Some(name_pv) -> #(["\"name\" = ?", ..set_parts], [
          sqlight.text(name_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"human\" set "
        <> set_sql
        <> " where \"email\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(email),
          ],
        ])
      #(sql, binds)
    }
    DeleteHumanByEmail(email:) -> #(human_delete_by_email_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(email),
    ])
    PatchHumanById(id:, name:, email:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case name {
        option.None -> #(set_parts, binds)
        option.Some(name_pv) -> #(["\"name\" = ?", ..set_parts], [
          sqlight.text(name_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case email {
        option.None -> #(set_parts, binds)
        option.Some(email_pv) -> #(["\"email\" = ?", ..set_parts], [
          sqlight.text(email_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"human\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
    UpdateHumanById(id:, name:, email:) -> #(human_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(name)),
      sqlight.text(api_help.opt_text_for_db(email)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
pub type HippoCommand {
  UpsertHippoByNameAndDateOfBirth(
    name: String,
    date_of_birth: calendar.Date,
    gender: option.Option(hippo_schema.GenderScalar),
  )
  UpdateHippoByNameAndDateOfBirth(
    name: String,
    date_of_birth: calendar.Date,
    gender: option.Option(hippo_schema.GenderScalar),
  )
  PatchHippoByNameAndDateOfBirth(
    name: String,
    date_of_birth: calendar.Date,
    gender: option.Option(hippo_schema.GenderScalar),
  )
  DeleteHippoByNameAndDateOfBirth(name: String, date_of_birth: calendar.Date)
  UpdateHippoById(
    id: Int,
    name: option.Option(String),
    gender: option.Option(hippo_schema.GenderScalar),
    date_of_birth: option.Option(calendar.Date),
  )
  PatchHippoById(
    id: Int,
    name: option.Option(String),
    gender: option.Option(hippo_schema.GenderScalar),
    date_of_birth: option.Option(calendar.Date),
  )
}

const hippo_upsert_by_name_and_date_of_birth_sql = "insert into \"hippo\" (\"name\", \"gender\", \"date_of_birth\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"name\", \"date_of_birth\") do update set
  \"gender\" = excluded.\"gender\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const hippo_update_by_name_and_date_of_birth_sql = "update \"hippo\" set \"gender\" = ?, \"updated_at\" = ? where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null;"

const hippo_delete_by_name_and_date_of_birth_sql = "update \"hippo\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null;"

const hippo_update_by_id_sql = "update \"hippo\" set \"name\" = ?, \"gender\" = ?, \"date_of_birth\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

pub fn execute_hippo_cmds(
  conn conn: sqlight.Connection,
  commands commands: List(HippoCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, hippo_variant_tag, plan_hippo)
}

fn hippo_variant_tag(cmd cmd: HippoCommand) -> Int {
  case cmd {
    UpsertHippoByNameAndDateOfBirth(..) -> 0
    UpdateHippoByNameAndDateOfBirth(..) -> 1
    PatchHippoByNameAndDateOfBirth(..) -> 2
    DeleteHippoByNameAndDateOfBirth(..) -> 3
    PatchHippoById(..) -> 4
    UpdateHippoById(..) -> 5
  }
}

fn plan_hippo(
  cmd cmd: HippoCommand,
  now now: Int,
) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertHippoByNameAndDateOfBirth(name:, date_of_birth:, gender:) -> #(
      hippo_upsert_by_name_and_date_of_birth_sql,
      [
        sqlight.text(name),
        sqlight.text(row.gender_scalar_to_db_string(gender)),
        sqlight.text(api_help.date_to_db_string(date_of_birth)),
        sqlight.int(now),
        sqlight.int(now),
      ],
    )
    UpdateHippoByNameAndDateOfBirth(name:, date_of_birth:, gender:) -> #(
      hippo_update_by_name_and_date_of_birth_sql,
      [
        sqlight.text(row.gender_scalar_to_db_string(gender)),
        sqlight.int(now),
        sqlight.text(name),
        sqlight.text(api_help.date_to_db_string(date_of_birth)),
      ],
    )
    PatchHippoByNameAndDateOfBirth(name:, date_of_birth:, gender:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case gender {
        option.None -> #(set_parts, binds)
        option.Some(gender_pv) -> #(["\"gender\" = ?", ..set_parts], [
          sqlight.text(row.gender_scalar_to_db_string(option.Some(gender_pv))),
          ..binds
        ])
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"hippo\" set "
        <> set_sql
        <> " where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null;"
      let binds =
        list.flatten([
          list.reverse(binds),
          [
            sqlight.text(name),
            sqlight.text(api_help.date_to_db_string(date_of_birth)),
          ],
        ])
      #(sql, binds)
    }
    DeleteHippoByNameAndDateOfBirth(name:, date_of_birth:) -> #(
      hippo_delete_by_name_and_date_of_birth_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(name),
        sqlight.text(api_help.date_to_db_string(date_of_birth)),
      ],
    )
    PatchHippoById(id:, name:, gender:, date_of_birth:) -> {
      let #(set_parts, binds) = #([], [])
      let #(set_parts, binds) = case name {
        option.None -> #(set_parts, binds)
        option.Some(name_pv) -> #(["\"name\" = ?", ..set_parts], [
          sqlight.text(name_pv),
          ..binds
        ])
      }
      let #(set_parts, binds) = case gender {
        option.None -> #(set_parts, binds)
        option.Some(gender_pv) -> #(["\"gender\" = ?", ..set_parts], [
          sqlight.text(row.gender_scalar_to_db_string(option.Some(gender_pv))),
          ..binds
        ])
      }
      let #(set_parts, binds) = case date_of_birth {
        option.None -> #(set_parts, binds)
        option.Some(date_of_birth_pv) -> #(
          ["\"date_of_birth\" = ?", ..set_parts],
          [sqlight.text(api_help.date_to_db_string(date_of_birth_pv)), ..binds],
        )
      }
      let #(set_parts, binds) = #(["\"updated_at\" = ?", ..set_parts], [
        sqlight.int(now),
        ..binds
      ])
      let set_sql = string.join(list.reverse(set_parts), ", ")
      let sql =
        "update \"hippo\" set "
        <> set_sql
        <> " where \"id\" = ? and \"deleted_at\" is null;"
      let binds = list.flatten([list.reverse(binds), [sqlight.int(id)]])
      #(sql, binds)
    }
    UpdateHippoById(id:, name:, gender:, date_of_birth:) -> #(
      hippo_update_by_id_sql,
      [
        sqlight.text(api_help.opt_text_for_db(name)),
        sqlight.text(row.gender_scalar_to_db_string(gender)),
        sqlight.text(case date_of_birth {
          option.Some(d) -> api_help.date_to_db_string(d)
          option.None -> ""
        }),
        sqlight.int(now),
        sqlight.int(id),
      ],
    )
  }
}
