/// Generic command-batch executor used by all generated `execute_*_cmds` functions.
///
/// Generated modules supply only the entity-specific parts (command type, SQL,
/// `plan`, `variant_tag`); this module owns the execution engine that is
/// identical for every entity.
import gleam/dynamic/decode
import gleam/list
import gleam/result
import sqlight
import swil/runtime/api_help

// ── Grouping helpers ──────────────────────────────────────────────────────────

fn take_same(
  items: List(#(Int, a)),
  tag: Int,
  tag_fn: fn(a) -> Int,
  acc: List(#(Int, a)),
) -> #(List(#(Int, a)), List(#(Int, a))) {
  case items {
    [] -> #(list.reverse(acc), [])
    [#(i, cmd), ..rest] ->
      case tag_fn(cmd) == tag {
        True -> take_same(rest, tag, tag_fn, [#(i, cmd), ..acc])
        False -> #(list.reverse(acc), items)
      }
  }
}

/// Split an indexed command list into contiguous same-variant batches.
/// Order is preserved; only consecutive equal-tag runs are merged.
fn group_by_variant(
  indexed: List(#(Int, a)),
  tag_fn: fn(a) -> Int,
) -> List(List(#(Int, a))) {
  case indexed {
    [] -> []
    [#(i, cmd), ..rest] -> {
      let tag = tag_fn(cmd)
      let #(same, remaining) = take_same(rest, tag, tag_fn, [])
      [[#(i, cmd), ..same], ..group_by_variant(remaining, tag_fn)]
    }
  }
}

// ── Batch executor ────────────────────────────────────────────────────────────

/// Execute one contiguous same-variant batch inside a single BEGIN/COMMIT.
/// SQLite otherwise auto-commits each statement (one fsync per row); a
/// transaction amortises that cost across the whole batch.
/// On failure the transaction is rolled back; the error carries the 0-based
/// index of the **first command in this batch**.
fn exec_batch(
  conn: sqlight.Connection,
  batch: List(#(Int, a)),
  plan_fn: fn(a, Int) -> #(String, List(sqlight.Value)),
  now: Int,
) -> Result(Nil, #(Int, sqlight.Error)) {
  let assert [#(batch_start, _), ..] = batch
  case sqlight.exec("BEGIN;", conn) {
    Error(e) -> Error(#(batch_start, e))
    Ok(_) -> {
      let batch_result =
        list.try_map(batch, fn(pair) {
          let #(_i, cmd) = pair
          let #(sql, bindings) = plan_fn(cmd, now)
          // No-op decoder: we only need success/failure, not returned rows.
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
          let _ = sqlight.exec("ROLLBACK;", conn)
          Error(#(batch_start, e))
        }
      }
    }
  }
}

// ── Public entry point ────────────────────────────────────────────────────────

/// Apply `commands` in order, batching consecutive same-variant runs into a
/// single `BEGIN`/`COMMIT` transaction each.
///
/// - `tag_fn` identifies the variant (same tag = same SQL shape = same batch lane).
/// - `plan_fn` maps a command + injected `now` timestamp to `#(sql, bindings)`.
/// - On failure: `Error(#(index, error))` where `index` is the 0-based position
///   of the first command in the failing batch. Preceding batches are committed.
pub fn run_cmds(
  conn: sqlight.Connection,
  commands: List(cmd),
  tag_fn: fn(cmd) -> Int,
  plan_fn: fn(cmd, Int) -> #(String, List(sqlight.Value)),
) -> Result(Nil, #(Int, sqlight.Error)) {
  let now = api_help.unix_seconds_now()
  let indexed = list.index_map(commands, fn(c, i) { #(i, c) })
  let batches = group_by_variant(indexed, tag_fn)
  use _ <- result.try(list.try_map(batches, fn(batch) {
    exec_batch(conn, batch, plan_fn, now)
  }))
  Ok(Nil)
}
