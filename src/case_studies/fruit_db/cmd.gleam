/// Commands-as-pure-data for the `fruit` entity.
///
/// Build command values without a connection; execute them all at once via
/// `execute_fruit_cmds`.  Consecutive same-variant commands are grouped into
/// a single BEGIN/COMMIT block by the shared executor in `swil/cmd_runner`.
///
/// WAL mode should be enabled on the connection before calling
/// `execute_fruit_cmds` to get the full throughput benefit.
import gleam/option.{type Option}
import sqlight
import swil/api_help
import swil/cmd_runner

// ── Command type ──────────────────────────────────────────────────────────────

/// Every distinct SQL shape the fruit entity supports, expressed as data.
///
/// Variants cover both identity-keyed operations (ByName) and the row-id
/// operations (ById) so that callers can freely mix them in a single list.
pub type FruitCommand {
  /// Insert or update a fruit row by its natural `name` key.
  UpsertFruitByName(
    name: String,
    color: Option(String),
    price: Option(Float),
    quantity: Option(Int),
  )
  /// Update mutable columns of a fruit row identified by its natural `name` key.
  UpdateFruitByName(
    name: String,
    color: Option(String),
    price: Option(Float),
    quantity: Option(Int),
  )
  /// Soft-delete a fruit row by its natural `name` key.
  DeleteFruitByName(name: String)
  /// Update all scalar columns of a fruit row identified by the magic row `id`.
  UpdateFruitById(
    id: Int,
    name: Option(String),
    color: Option(String),
    price: Option(Float),
    quantity: Option(Int),
  )
}

// ── Private SQL (no RETURNING — executor only needs Result(Nil)) ──────────────

/// Bindings: name, color, price, quantity, created_at, updated_at
const upsert_by_name_sql = "insert into \"fruit\" (\"name\", \"color\", \"price\", \"quantity\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"color\" = excluded.\"color\",
  \"price\" = excluded.\"price\",
  \"quantity\" = excluded.\"quantity\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

/// Bindings: color, price, quantity, updated_at, name
const update_by_name_sql = "update \"fruit\" set \"color\" = ?, \"price\" = ?, \"quantity\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

/// Bindings: deleted_at (now), updated_at (now), name
const delete_by_name_sql = "update \"fruit\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

/// Bindings: name, color, price, quantity, updated_at, id
const update_by_id_sql = "update \"fruit\" set \"name\" = ?, \"color\" = ?, \"price\" = ?, \"quantity\" = ?, \"updated_at\" = ? where \"id\" = ? and \"deleted_at\" is null;"

// ── Private planner ───────────────────────────────────────────────────────────

/// Map a command to its SQL string and bind list.
/// `now` is injected here (not stored on the command) per the spec decision.
fn plan(cmd: FruitCommand, now: Int) -> #(String, List(sqlight.Value)) {
  case cmd {
    UpsertFruitByName(name:, color:, price:, quantity:) -> #(
      upsert_by_name_sql,
      [
        sqlight.text(name),
        sqlight.text(api_help.opt_text_for_db(color)),
        sqlight.float(api_help.opt_float_for_db(price)),
        sqlight.int(api_help.opt_int_for_db(quantity)),
        sqlight.int(now),
        // created_at
        sqlight.int(now),
        // updated_at
      ],
    )
    UpdateFruitByName(name:, color:, price:, quantity:) -> #(
      update_by_name_sql,
      [
        sqlight.text(api_help.opt_text_for_db(color)),
        sqlight.float(api_help.opt_float_for_db(price)),
        sqlight.int(api_help.opt_int_for_db(quantity)),
        sqlight.int(now),
        // updated_at
        sqlight.text(name),
        // WHERE name = ?
      ],
    )
    DeleteFruitByName(name:) -> #(
      delete_by_name_sql,
      [
        sqlight.int(now),
        // deleted_at
        sqlight.int(now),
        // updated_at
        sqlight.text(name),
        // WHERE name = ?
      ],
    )
    UpdateFruitById(id:, name:, color:, price:, quantity:) -> #(
      update_by_id_sql,
      [
        sqlight.text(api_help.opt_text_for_db(name)),
        sqlight.text(api_help.opt_text_for_db(color)),
        sqlight.float(api_help.opt_float_for_db(price)),
        sqlight.int(api_help.opt_int_for_db(quantity)),
        sqlight.int(now),
        // updated_at
        sqlight.int(id),
        // WHERE id = ?
      ],
    )
  }
}

// ── Variant tag ───────────────────────────────────────────────────────────────

/// An integer tag so the runner can group consecutive same-variant commands.
/// Different tags = different SQL shapes = different batch lanes.
fn variant_tag(cmd: FruitCommand) -> Int {
  case cmd {
    UpsertFruitByName(..) -> 0
    UpdateFruitByName(..) -> 1
    DeleteFruitByName(..) -> 2
    UpdateFruitById(..) -> 3
  }
}

// ── Public executor ───────────────────────────────────────────────────────────

/// Apply `commands` in order, batching consecutive same-variant runs into a
/// single `BEGIN`/`COMMIT` transaction each.
///
/// - Single op: `execute_fruit_cmds(conn, [cmd])`.
/// - On failure, returns `Error(#(index, error))` where `index` is the
///   0-based position of the **first command in the failing batch**.
/// - Preceding batches are already committed; no global rollback.
/// - SQL and binding details are private to this module.
pub fn execute_fruit_cmds(
  conn: sqlight.Connection,
  commands: List(FruitCommand),
) -> Result(Nil, #(Int, sqlight.Error)) {
  cmd_runner.run_cmds(conn, commands, variant_tag, plan)
}
