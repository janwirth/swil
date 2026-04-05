/// Commands-as-pure-data for the `fruit` entity.
///
/// Build command values without a connection; execute them all at once via
/// `execute_fruit_cmds`.  Consecutive same-variant commands are grouped into
/// a single BEGIN/COMMIT block, eliminating one fsync per row.
///
/// WAL mode should be enabled on the connection before calling
/// `execute_fruit_cmds` to get the full throughput benefit.
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/result
import sqlight
import swil/api_help

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

/// Upsert by name: inserts or updates via ON CONFLICT on "name".
/// Bindings: name, color, price, quantity, created_at, updated_at
const upsert_by_name_sql = "insert into \"fruit\" (\"name\", \"color\", \"price\", \"quantity\", \"created_at\", \"updated_at\", \"deleted_at\")
values (?, ?, ?, ?, ?, ?, null)
on conflict(\"name\") do update set
  \"color\" = excluded.\"color\",
  \"price\" = excluded.\"price\",
  \"quantity\" = excluded.\"quantity\",
  \"updated_at\" = excluded.\"updated_at\",
  \"deleted_at\" = null;"

/// Update mutable columns by name.
/// Bindings: color, price, quantity, updated_at, name
const update_by_name_sql = "update \"fruit\" set \"color\" = ?, \"price\" = ?, \"quantity\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

/// Soft-delete by name: sets deleted_at and updated_at.
/// Bindings: deleted_at (now), updated_at (now), name
const delete_by_name_sql = "update \"fruit\" set \"deleted_at\" = ?, \"updated_at\" = ? where \"name\" = ? and \"deleted_at\" is null;"

/// Update all scalar columns by row id.
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
        // created_at and updated_at are both `now`; the conflict handler
        // only touches updated_at on an existing row.
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

// ── Variant tagging for grouping ──────────────────────────────────────────────

/// An integer tag so we can group consecutive same-variant commands.
/// Different tags = different SQL shapes = different batch lanes.
fn variant_tag(cmd: FruitCommand) -> Int {
  case cmd {
    UpsertFruitByName(..) -> 0
    UpdateFruitByName(..) -> 1
    DeleteFruitByName(..) -> 2
    UpdateFruitById(..) -> 3
  }
}

// ── Grouping ──────────────────────────────────────────────────────────────────

/// Accumulate items into one run while their variant tag matches `tag`.
fn take_same(
  items: List(#(Int, FruitCommand)),
  tag: Int,
  acc: List(#(Int, FruitCommand)),
) -> #(List(#(Int, FruitCommand)), List(#(Int, FruitCommand))) {
  case items {
    [] -> #(list.reverse(acc), [])
    [#(i, cmd), ..rest] ->
      case variant_tag(cmd) == tag {
        True -> take_same(rest, tag, [#(i, cmd), ..acc])
        False -> #(list.reverse(acc), items)
      }
  }
}

/// Split an indexed command list into contiguous same-variant batches.
/// Order is preserved; only consecutive equal-variant runs are grouped.
fn group_by_variant(
  indexed: List(#(Int, FruitCommand)),
) -> List(List(#(Int, FruitCommand))) {
  case indexed {
    [] -> []
    [#(i, cmd), ..rest] -> {
      let tag = variant_tag(cmd)
      let #(same, remaining) = take_same(rest, tag, [])
      [[#(i, cmd), ..same], ..group_by_variant(remaining)]
    }
  }
}

// ── Batch executor ────────────────────────────────────────────────────────────

/// Execute one contiguous same-variant batch inside a BEGIN/COMMIT transaction.
/// Using a transaction avoids one implicit fsync per statement in SQLite.
/// On any failure the transaction is rolled back and the error is returned with
/// the 0-based index of the **first command in this batch** (not the failing
/// individual command within it).
fn exec_batch(
  conn: sqlight.Connection,
  batch: List(#(Int, FruitCommand)),
  now: Int,
) -> Result(Nil, #(Int, sqlight.Error)) {
  let assert [#(batch_start, _), ..] = batch
  case sqlight.exec("BEGIN;", conn) {
    Error(e) -> Error(#(batch_start, e))
    Ok(_) -> {
      // Execute each command sequentially; list.try_map stops on first error.
      let batch_result =
        list.try_map(batch, fn(pair) {
          let #(_i, cmd) = pair
          let #(sql, bindings) = plan(cmd, now)
          // Use query with a no-op decoder; we only care about success/failure.
          use _ <- result.try(sqlight.query(
            sql,
            on: conn,
            with: bindings,
            expecting: decode.success(Nil),
          ))
          Ok(Nil)
        })
      case batch_result {
        Ok(_) ->
          case sqlight.exec("COMMIT;", conn) {
            Ok(_) -> Ok(Nil)
            Error(e) -> Error(#(batch_start, e))
          }
        Error(e) -> {
          // Best-effort rollback; ignore rollback errors.
          let _ = sqlight.exec("ROLLBACK;", conn)
          Error(#(batch_start, e))
        }
      }
    }
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
  let now = api_help.unix_seconds_now()
  // Attach 0-based indices before grouping so error reporting stays accurate.
  let indexed = list.index_map(commands, fn(cmd, i) { #(i, cmd) })
  let batches = group_by_variant(indexed)
  // Execute each batch; stop at first failure.
  use _ <- result.try(list.try_map(batches, fn(batch) {
    exec_batch(conn, batch, now)
  }))
  Ok(Nil)
}
