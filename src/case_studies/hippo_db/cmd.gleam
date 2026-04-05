/// Commands-as-pure-data for this schema's entities.
/// Generated — do not edit by hand.
/// Execute via `execute_<entity>_cmds`; see `swil/cmd_runner` for batching.
import case_studies/hippo_db/row
import case_studies/hippo_schema
import gleam/option
import gleam/time/calendar
import sqlight
import swil/api_help
import swil/cmd_runner

/// Upsert/update payload for `ByNameAndDateOfBirth` identity on `Hippo`.
pub type HippoByNameAndDateOfBirth {
  HippoByNameAndDateOfBirth(
    name: String,
    date_of_birth: calendar.Date,
    gender: option.Option(hippo_schema.GenderScalar),
  )
}

pub type HippoCommand {
  /// Upsert by `ByNameAndDateOfBirth` identity.
  UpsertHippoByNameAndDateOfBirth(
    name: String,
    date_of_birth: calendar.Date,
    gender: option.Option(hippo_schema.GenderScalar),
  )
  /// Update by `ByNameAndDateOfBirth` identity.
  UpdateHippoByNameAndDateOfBirth(
    name: String,
    date_of_birth: calendar.Date,
    gender: option.Option(hippo_schema.GenderScalar),
  )
  /// Soft-delete by `ByNameAndDateOfBirth` identity.
  DeleteHippoByNameAndDateOfBirth(name: String, date_of_birth: calendar.Date)
  /// Update all scalar columns by row `id`.
  UpdateHippoById(
    id: Int,
    name: option.Option(String),
    gender: option.Option(hippo_schema.GenderScalar),
    date_of_birth: option.Option(calendar.Date),
  )
}

/// Upsert/update payload for `ByEmail` identity on `Human`.
pub type HumanByEmail {
  HumanByEmail(email: String, name: option.Option(String))
}

pub type HumanCommand {
  /// Upsert by `ByEmail` identity.
  UpsertHumanByEmail(email: String, name: option.Option(String))
  /// Update by `ByEmail` identity.
  UpdateHumanByEmail(email: String, name: option.Option(String))
  /// Soft-delete by `ByEmail` identity.
  DeleteHumanByEmail(email: String)
  /// Update all scalar columns by row `id`.
  UpdateHumanById(
    id: Int,
    name: option.Option(String),
    email: option.Option(String),
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

const human_upsert_by_email_sql = "insert into \"human\" (\"name\", \"email\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"email\") do update set
  \"name\" = excluded.\"name\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

const human_update_by_email_sql = "update \"human\" set \"name\" = ?, \"updated_at\" = ? where \"email\" = ? and \"deleted_at\" is null;"

const human_delete_by_email_sql = "update \"human\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"email\" = ? and \"deleted_at\" is null;"

const human_update_by_id_sql = "update \"human\" set \"name\" = ?, \"email\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

fn plan_hippo(cmd: HippoCommand, now: Int) -> #(String, List(sqlight.Value)) {
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
    DeleteHippoByNameAndDateOfBirth(name:, date_of_birth:) -> #(
      hippo_delete_by_name_and_date_of_birth_sql,
      [
        sqlight.int(now),
        sqlight.int(now),
        sqlight.text(name),
        sqlight.text(api_help.date_to_db_string(date_of_birth)),
      ],
    )
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

fn plan_human(cmd: HumanCommand, now: Int) -> #(String, List(sqlight.Value)) {
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
    DeleteHumanByEmail(email:) -> #(human_delete_by_email_sql, [
      sqlight.int(now),
      sqlight.int(now),
      sqlight.text(email),
    ])
    UpdateHumanById(id:, name:, email:) -> #(human_update_by_id_sql, [
      sqlight.text(api_help.opt_text_for_db(name)),
      sqlight.text(api_help.opt_text_for_db(email)),
      sqlight.int(now),
      sqlight.int(id),
    ])
  }
}

fn hippo_variant_tag(cmd: HippoCommand) -> Int {
  case cmd {
    UpsertHippoByNameAndDateOfBirth(..) -> 0
    UpdateHippoByNameAndDateOfBirth(..) -> 1
    DeleteHippoByNameAndDateOfBirth(..) -> 2
    UpdateHippoById(..) -> 3
  }
}

fn human_variant_tag(cmd: HumanCommand) -> Int {
  case cmd {
    UpsertHumanByEmail(..) -> 0
    UpdateHumanByEmail(..) -> 1
    DeleteHumanByEmail(..) -> 2
    UpdateHumanById(..) -> 3
  }
}

pub fn execute_hippo_cmds(
  conn: sqlight.Connection,
  commands: List(HippoCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, hippo_variant_tag, plan_hippo)
}

pub fn execute_human_cmds(
  conn: sqlight.Connection,
  commands: List(HumanCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, human_variant_tag, plan_human)
}
