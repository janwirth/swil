//// Parser IR for `dsl.shape`: custom projections (`Subset`) vs full entity (`NoneOrBase`).
//// See CUSTOM_SHAPE_SPEC.md. Codegen must eventually match this IR (SQL `select` + row type).

import gleam/list
import gleam/option.{Some}
import gleeunit
import schema_definition/parser as schema_parser
import schema_definition/schema_definition as sd
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

fn get_query_by_name(
  def: sd.SchemaDefinition,
  name: String,
) -> sd.QuerySpecDefinition {
  let assert Ok(q) =
    list.find(in: def.queries, one_that: fn(q) { q.name == name })
  q
}

/// `hippo_schema.query_old_hippos_owner_emails`: tuple shape with explicit `age` and `owner_email`.
pub fn hippo_old_hippos_owner_emails_shape_subset_test() {
  let assert Ok(src) = simplifile.read("test/case_studies/hippo_schema.gleam")
  let assert Ok(def) = schema_parser.parse_module(src)
  let q = get_query_by_name(def, "query_old_hippos_owner_emails")
  let assert sd.Subset(selection: fields) = q.query.shape
  assert list.length(fields) == 2
  let assert [
    sd.ShapeField(alias: Some("age"), expr: age_expr),
    sd.ShapeField(alias: Some("owner_email"), expr: email_expr),
  ] = fields
  let assert sd.Call(sd.AgeFn, [sd.Call(sd.ExcludeIfMissingFn, [sd.Field(path: dob)])]) =
    age_expr
  assert dob == ["hippo", "date_of_birth"]
  let assert sd.Call(sd.NullableFn, [sd.Field(path: owner_path)]) = email_expr
  assert owner_path == ["hippo", "relationships", "owner", "item", "email"]
}

/// Minimal module: shape lists only row id from `dsl.MagicFields` (auto alias `id`).
pub fn query_shape_magic_id_only_parses_test() {
  let input =
    "import swil/dsl as dsl
import gleam/option

pub type Row {
  Row(identities: RowIdentities)
}

pub type RowIdentities {
  ByKey(key: String)
}

pub fn query_row_ids(row: Row, magic: dsl.MagicFields, _unused: Int) {
  dsl.query(row)
  |> dsl.shape(#(magic.id))
  |> dsl.filter_bool(option.None)
  |> dsl.order_by(option.None, dsl.Desc)
}
"
  let assert Ok(def) = schema_parser.parse_module(input)
  let assert [q] = def.queries
  assert q.name == "query_row_ids"
  let assert sd.Subset(selection: [only]) = q.query.shape
  let assert sd.ShapeField(alias: Some("id"), expr: sd.Field(path: id_path)) = only
  assert id_path == ["magic", "id"]
}
