import gleam/io
import gleam/list
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

/// `library_manager_schema.gleam.gleam` is intentionally not a hippo-style schema.
/// `schema_definition.parse_module` stops at the first violation (order of `custom_types` from Glance).
/// This test prints that error, then a checklist of other problems in the file.
pub fn library_manager_schema_rejected_test() {
  let path = "src/case_studies/library_manager_schema.gleam.gleam"
  let assert Ok(src) = simplifile.read(path)

  case schema_definition.parse_module(src) {
    Ok(_) -> panic as "expected library_manager schema to be rejected by strict parser"
    Error(schema_definition.GlanceError(_)) ->
      panic as "unexpected Glance parse failure (file should lex/parse)"
    Error(schema_definition.UnsupportedSchema(message)) -> {
      io.println("\n========== library_manager schema rejection ==========")
      io.println("file: " <> path)
      io.println("\n--- first error from schema_definition.parse_module ---")
      io.println(message)
      io.println(
        "\n--- other violations in this file (would also fail once earlier issues are fixed) ---",
      )
      io.println(
        "  • OrderBy(field) (≈line 136): generic type parameters are rejected for schema modules\n"
        <> "    (often the first error Glance reports among public types).",
      )
      io.println(
        "  • ImportedTrack (≈line 8): squeal entity record must include both\n"
        <> "    labelled fields `identities: *Identities` and `relationships: *Relationships`.\n"
        <> "    This type only has `identities`.",
      )
      io.println(
        "  • Tag (≈line 23): not a scalar enum, not *Identities / *Relationships / *Attributes,\n"
        <> "    and not an entity (no identities+relationships). Unsupported shape.",
      )
      io.println(
        "  • ResolvedIdentity (≈line 37): same as Tag — plain struct, not in the allowed set.",
      )
      io.println(
        "  • Tab (≈line 54): multi-variant sum type; only scalar enums (all empty variants)\n"
        <> "    or identity bundles (*Identities with `By…` variants) may have multiple variants.",
      )
      io.println(
        "  • FilterConfig (≈line 69): no variants in the AST → not allowed (no opaque bucket).",
      )
      io.println(
        "  • Public functions e.g. `all_tabs` (≈line 95): every public fn must be a Query spec\n"
        <> "    (return type or trailing `Query(...)`) with fully typed parameters.\n"
        <> "    Parser may fail earlier on types before it reaches functions.",
      )
      io.println("========================================================\n")
      Nil
    }
  }
}
