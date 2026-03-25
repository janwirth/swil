import dsl/parser_error_formatter
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit
import schema_definition
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
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

pub fn library_manager_schema_test() {
  let path = "src/case_studies/library_manager_schema.gleam"
  let assert Ok(src) = simplifile.read(path)

  let assert Ok(def) = schema_definition.parse_module(src)
}
