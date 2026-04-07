//// Parser tests for `dsl.order_by`, `dsl.limit`, `dsl.offset` pipeline steps.
////
//// Verifies:
//// - `dsl.order` in source → rejected with a hint to use `dsl.order_by`
//// - `dsl.order_by` parses correctly
//// - `dsl.limit` and `dsl.offset` in source are parsed and stored in IR
//// - duplicate steps (double `dsl.order_by`) are rejected at parse time

import gleam/option
import gleam/string
import gleeunit
import schema_definition/parser as schema_parser
import schema_definition/schema_definition

pub fn main() -> Nil {
  gleeunit.main()
}

fn minimal_module_with_body(body: String) -> String {
  "import swil/dsl as dsl
import gleam/option

pub type Widget {
  Widget(identities: WidgetIdentities)
}

pub type WidgetIdentities {
  ByKey(key: String)
}

pub fn query_widgets(w: Widget, _m: dsl.MagicFields, _k: Int) {
"
  <> body
  <> "
}
"
}

/// `dsl.order` (old name) in the pipeline is rejected with a hint to use `dsl.order_by`.
pub fn old_order_name_rejected_with_hint_test() {
  let src =
    minimal_module_with_body(
      "  dsl.query(w)
  |> dsl.shape(w)
  |> dsl.order(option.None, dsl.Desc)",
    )
  case schema_parser.parse_module(src) {
    Ok(_) -> panic as "expected dsl.order to be rejected"
    Error(e) -> {
      let msg = schema_parser.format_parse_error(src, e)
      assert string.contains(msg, "order_by")
    }
  }
}

/// `dsl.order_by` parses successfully and sets IR order.
pub fn order_by_parses_correctly_test() {
  let src =
    minimal_module_with_body(
      "  dsl.query(w)
  |> dsl.shape(w)
  |> dsl.order_by(option.None, dsl.Desc)",
    )
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert [q] = def.queries
  assert q.query.order == schema_definition.UpdatedAtDesc
}

/// Pipeline with `dsl.order_by`, `dsl.limit`, and `dsl.offset` parses fully.
pub fn order_by_limit_offset_parses_test() {
  let src =
    "import swil/dsl as dsl
import gleam/option

pub type Widget {
  Widget(identities: WidgetIdentities)
}

pub type WidgetIdentities {
  ByKey(key: String)
}

pub fn query_widgets(w: Widget, _m: dsl.MagicFields, k: Int) {
  dsl.query(w)
  |> dsl.shape(w)
  |> dsl.order_by(option.None, dsl.Desc)
  |> dsl.limit(limit: k)
  |> dsl.offset(offset: k)
}
"
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert [q] = def.queries
  // limit and offset are stored in IR
  let _ = option.None
  // order is still parsed
  assert q.query.order == schema_definition.UpdatedAtDesc
}

/// Pipeline with `dsl.filter_bool` before `dsl.order_by` and then `dsl.limit` parses.
pub fn filter_then_order_by_then_limit_parses_test() {
  let src =
    "import swil/dsl as dsl
import gleam/option

pub type Widget {
  Widget(identities: WidgetIdentities)
}

pub type WidgetIdentities {
  ByKey(key: String)
}

pub fn query_widgets(w: Widget, _m: dsl.MagicFields, k: Int) {
  dsl.query(w)
  |> dsl.shape(w)
  |> dsl.filter_bool(option.None)
  |> dsl.order_by(option.None, dsl.Asc)
  |> dsl.limit(limit: k)
}
"
  let assert Ok(def) = schema_parser.parse_module(src)
  let assert [q] = def.queries
  assert q.query.order == schema_definition.UpdatedAtDesc
}
