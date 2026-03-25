import gleam/io
import gleam/list
import gleam/string
import gleam/option.{None, Some}
import gleeunit
import schema_definition
import schema_diagnostics
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

fn nth_line(source: String, line_no: Int) -> String {
  let lines = string.split(source, "\n")
  case list.drop(from: lines, up_to: line_no - 1) {
    [row, ..] -> row
    [] -> ""
  }
}

fn println_reference_line(src: String, line_no: Int, message: String) -> Nil {
  io.println(schema_diagnostics.format_reference_line(
    line_no,
    nth_line(src, line_no),
    message,
  ))
  io.println("")
}

fn println_fix_entity_constructor_matches_type() -> Nil {
  io.println(
    "  • The record constructor must reuse the type name (e.g. `pub type Tab { Tab(...) }`).",
  )
  io.println("")
}

fn println_valid_query_spec_example() -> Nil {
  io.println(
    "  • Public query specs must return `Query(...)` (or use a `-> Query` return annotation) and type every parameter.",
  )
  io.println("  • For example:")
  io.println("")
  io.println(
    "    pub fn rows_matching_status(row: Row, want: StatusScalar) {",
  )
  io.println(
    "      Query(shape: option.None, filter: option.None, order: option.None)",
  )
  io.println("    }")
  io.println("")
}

pub fn hippo_schema_parses_test() {
  let assert Ok(src) = simplifile.read("src/case_studies/hippo_schema.gleam")
  let assert Ok(def) = schema_definition.parse_module(src)

  let entity_names =
    list.map(def.entities, fn(e) { e.type_name })
    |> list.sort(string.compare)

  let identity_names =
    list.map(def.identities, fn(i) { i.type_name })
    |> list.sort(string.compare)

  let query_names =
    list.map(def.queries, fn(q) { q.name }) |> list.sort(string.compare)

  assert entity_names == ["Hippo", "Human"]

  assert identity_names == ["HippoIdentities", "HumanIdentities"]

  assert list.length(def.scalars) == 1
  let assert [scalar] = def.scalars
  assert scalar.type_name == "GenderScalar"
  assert scalar.variant_names == ["Male", "Female"]

  assert query_names == ["hippos_by_gender", "old_hippos_owner_emails"]

  let rel_container_names =
    list.map(def.relationship_containers, fn(r) { r.type_name })
    |> list.sort(string.compare)
  assert rel_container_names == ["HippoRelationships", "HumanRelationships"]

  let edge_attr_names =
    list.map(def.relationship_edge_attributes, fn(a) { a.type_name })
    |> list.sort(string.compare)
  assert edge_attr_names == ["FriendshipAttributes"]

  let assert Ok(hippo) =
    list.find(in: def.entities, one_that: fn(e) { e.type_name == "Hippo" })
  assert hippo.identity_type_name == "HippoIdentities"
  assert hippo.variant_name == "Hippo"

  let assert Ok(human) =
    list.find(in: def.entities, one_that: fn(e) { e.type_name == "Human" })
  assert human.identity_type_name == "HumanIdentities"

  let assert Ok(hippo_id) =
    list.find(in: def.identities, one_that: fn(i) {
      i.type_name == "HippoIdentities"
    })
  let assert [by_name] = hippo_id.variants
  assert by_name.variant_name == "ByNameAndDateOfBirth"
  assert list.length(by_name.fields) == 2
}

/// Entity with only `identities` (no `relationships`) is accepted.
pub fn entity_without_relationships_parses_test() {
  let src =
    "import gleam/option\n\npub type X {\n"
    <> "  X(name: option.Option(String), identities: XIdentities)\n"
    <> "}\n\npub type XIdentities {\n"
    <> "  ByName(name: String)\n"
    <> "}\n"
  let assert Ok(def) = schema_definition.parse_module(src)
  let assert [e] = def.entities
  assert e.type_name == "X"
  assert e.identity_type_name == "XIdentities"
}

/// `library_manager_schema.gleam.gleam` is intentionally not a hippo-style schema.
/// `parse_module` stops at the first violation; this test prints that finding, then
/// additional locations in **source order** as one continuous sequence.
pub fn library_manager_schema_rejected_test() {
  let path = "src/case_studies/library_manager_schema.gleam.gleam"
  let assert Ok(src) = simplifile.read(path)

  case schema_definition.parse_module(src) {
    Ok(_) -> panic as "expected library_manager schema to be rejected by strict parser"
    Error(parse_err) -> {
      io.println("\n========== library_manager schema rejection ==========")
      io.println("file: " <> path)
      io.println("")
      case parse_err {
        schema_definition.GlanceError(e) ->
          io.println(schema_diagnostics.format_glance_parse_error(src, e))
        schema_definition.UnsupportedSchema(Some(span), message) ->
          io.println(schema_diagnostics.format_source_diagnostic(
            src,
            span,
            message,
          ))
        schema_definition.UnsupportedSchema(None, message) ->
          io.println(schema_diagnostics.format_diagnostic_without_span(message))
      }
      io.println("")
      println_fix_entity_constructor_matches_type()
      println_reference_line(
        src,
        111,
        "public function must return a Query (annotation or trailing Query(...))",
      )
      println_valid_query_spec_example()
      io.println("========================================================\n")
      Nil
    }
  }
}
