/// Commands-as-pure-data for the `hippo` module (covers both the `hippo` and
/// `human` tables, each with its own command type and executor).
///
/// Build command values without a connection; execute them via
/// `execute_hippo_cmds` or `execute_human_cmds`.  The shared execution engine
/// lives in `swil/cmd_runner`; this module supplies only the entity-specific
/// command types, SQL, and planners.
///
/// WAL mode should be enabled on the connection before calling either executor.
import gleam/option.{type Option}
import gleam/time/calendar.{type Date}
import sqlight
import swil/api_help
import swil/cmd_runner
import case_studies/hippo_db/row
import case_studies/hippo_schema.{type GenderScalar}

// ── HippoCommand ──────────────────────────────────────────────────────────────

/// Every distinct SQL shape for the `hippo` table.
pub type HippoCommand {
  /// Insert or update a hippo by its composite natural key (name + date_of_birth).
  UpsertHippoByNameAndDateOfBirth(
    name: String,
    date_of_birth: Date,
    gender: Option(GenderScalar),
  )
  /// Update the mutable column (gender) identified by the natural key.
  UpdateHippoByNameAndDateOfBirth(
    name: String,
    date_of_birth: Date,
    gender: Option(GenderScalar),
  )
  /// Soft-delete a hippo row by its natural key.
  DeleteHippoByNameAndDateOfBirth(name: String, date_of_birth: Date)
  /// Update all scalar columns of a hippo row identified by the magic row `id`.
  UpdateHippoById(
    id: Int,
    name: Option(String),
    gender: Option(GenderScalar),
    date_of_birth: Option(Date),
  )
}

// ── HumanCommand ──────────────────────────────────────────────────────────────

/// Every distinct SQL shape for the `human` table.
pub type HumanCommand {
  /// Insert or update a human by the natural `email` key.
  UpsertHumanByEmail(email: String, name: Option(String))
  /// Update the mutable column (name) identified by email.
  UpdateHumanByEmail(email: String, name: Option(String))
  /// Soft-delete a human row by email.
  DeleteHumanByEmail(email: String)
  /// Update all scalar columns of a human row identified by the magic row `id`.
  UpdateHumanById(id: Int, name: Option(String), email: Option(String))
}

// ── Private SQL — hippo (no RETURNING) ───────────────────────────────────────

/// Bindings: name, gender, date_of_birth, created_at, updated_at
const hippo_upsert_by_key_sql = "insert into \"hippo\" (\"name\", \"gender\", \"date_of_birth\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, null)
on conflict(\"name\", \"date_of_birth\") do update set
  \"gender\" = excluded.\"gender\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

/// Bindings: gender, updated_at, name, date_of_birth
const hippo_update_by_key_sql = "update \"hippo\" set \"gender\" = ?, \"updated_at\" = ? where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null;"

/// Bindings: deleted_at (now), updated_at (now), name, date_of_birth
const hippo_delete_by_key_sql = "update \"hippo\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"date_of_birth\" = ? and \"deleted_at\" is null;"

/// Bindings: name, gender, date_of_birth, updated_at, id
const hippo_update_by_id_sql = "update \"hippo\" set \"name\" = ?, \"gender\" = ?, \"date_of_birth\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

// ── Private SQL — human (no RETURNING) ───────────────────────────────────────

/// Bindings: name, email, created_at, updated_at
const human_upsert_by_email_sql = "insert into \"human\" (\"name\", \"email\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, null)
on conflict(\"email\") do update set
  \"name\" = excluded.\"name\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

/// Bindings: name, updated_at, email
const human_update_by_email_sql = "update \"human\" set \"name\" = ?, \"updated_at\" = ? where \"email\" = ? and \"deleted_at\" is null;"

/// Bindings: deleted_at (now), updated_at (now), email
const human_delete_by_email_sql = "update \"human\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"email\" = ? and \"deleted_at\" is null;"

/// Bindings: name, email, updated_at, id
const human_update_by_id_sql = "update \"human\" set \"name\" = ?, \"email\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

// ── Private planners ──────────────────────────────────────────────────────────

fn plan_hippo(cmd: HippoCommand, now: Int) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertHippoByNameAndDateOfBirth(name:, date_of_birth:, gender:) -> #(
      hippo_upsert_by_key_sql,
      [
        sqlight.text(name),
        sqlight.text(row.gender_scalar_to_db_string(gender)),
        sqlight.text(api_help.date_to_db_string(date_of_birth)),
        sqlight.int(now),
        // created_at
        sqlight.int(now),
        // updated_at
      ],
    )
    UpdateHippoByNameAndDateOfBirth(name:, date_of_birth:, gender:) -> #(
      hippo_update_by_key_sql,
      [
        sqlight.text(row.gender_scalar_to_db_string(gender)),
        sqlight.int(now),
        // updated_at
        sqlight.text(name),
        sqlight.text(api_help.date_to_db_string(date_of_birth)),
      ],
    )
    DeleteHippoByNameAndDateOfBirth(name:, date_of_birth:) -> #(
      hippo_delete_by_key_sql,
      [
        sqlight.int(now),
        // deleted_at
        sqlight.int(now),
        // updated_at
        sqlight.text(name),
        sqlight.text(api_help.date_to_db_string(date_of_birth)),
      ],
    )
    UpdateHippoById(id:, name:, gender:, date_of_birth:) -> #(
      hippo_update_by_id_sql,
      [
        sqlight.text(api_help.opt_text_for_db(name)),
        sqlight.text(row.gender_scalar_to_db_string(gender)),
        // Empty string encodes absent date, matching the opt_text sentinel.
        sqlight.text(case date_of_birth {
          option.Some(d) -> api_help.date_to_db_string(d)
          option.None -> ""
        }),
        sqlight.int(now),
        // updated_at
        sqlight.int(id),
        // WHERE id = ?
      ],
    )
  }
}

fn plan_human(cmd: HumanCommand, now: Int) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertHumanByEmail(email:, name:) -> #(
      human_upsert_by_email_sql,
      [
        sqlight.text(api_help.opt_text_for_db(name)),
        sqlight.text(email),
        sqlight.int(now),
        // created_at
        sqlight.int(now),
        // updated_at
      ],
    )
    UpdateHumanByEmail(email:, name:) -> #(
      human_update_by_email_sql,
      [
        sqlight.text(api_help.opt_text_for_db(name)),
        sqlight.int(now),
        // updated_at
        sqlight.text(email),
        // WHERE email = ?
      ],
    )
    DeleteHumanByEmail(email:) -> #(
      human_delete_by_email_sql,
      [
        sqlight.int(now),
        // deleted_at
        sqlight.int(now),
        // updated_at
        sqlight.text(email),
        // WHERE email = ?
      ],
    )
    UpdateHumanById(id:, name:, email:) -> #(
      human_update_by_id_sql,
      [
        sqlight.text(api_help.opt_text_for_db(name)),
        sqlight.text(api_help.opt_text_for_db(email)),
        sqlight.int(now),
        // updated_at
        sqlight.int(id),
        // WHERE id = ?
      ],
    )
  }
}

// ── Variant tags ──────────────────────────────────────────────────────────────

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

// ── Public executors ──────────────────────────────────────────────────────────

/// Apply `commands` (hippo table) in order, batching consecutive same-variant
/// runs into a single BEGIN/COMMIT each.
pub fn execute_hippo_cmds(
  conn: sqlight.Connection,
  commands: List(HippoCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, hippo_variant_tag, plan_hippo)
}

/// Apply `commands` (human table) in order, batching consecutive same-variant
/// runs into a single BEGIN/COMMIT each.
pub fn execute_human_cmds(
  conn: sqlight.Connection,
  commands: List(HumanCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, human_variant_tag, plan_human)
}
