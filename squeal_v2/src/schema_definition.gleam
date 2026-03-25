import glance
import glance_armstrong
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Parsed view of a squeal schema module in the **hippo shape** only (see parser rules).
pub type SchemaDefinition {
  SchemaDefinition(
    entities: List(EntityDefinition),
    identities: List(IdentityTypeDefinition),
    relationship_containers: List(RelationshipContainerDefinition),
    relationship_edge_attributes: List(RelationshipEdgeAttributesDefinition),
    scalars: List(ScalarTypeDefinition),
    queries: List(QuerySpecDefinition),
  )
}

/// Aggregate root: single record variant named like the type, with required `identities` and optional `relationships`.
pub type EntityDefinition {
  EntityDefinition(
    type_name: String,
    variant_name: String,
    fields: List(FieldDefinition),
    identity_type_name: String,
  )
}

pub type FieldDefinition {
  FieldDefinition(label: String, type_: glance.Type)
}

/// `*Identities` type: each variant is `By…` with labelled fields only.
pub type IdentityTypeDefinition {
  IdentityTypeDefinition(
    type_name: String,
    variants: List(IdentityVariantDefinition),
  )
}

pub type IdentityVariantDefinition {
  IdentityVariantDefinition(variant_name: String, fields: List(FieldDefinition))
}

pub type VariantWithFields {
  VariantWithFields(variant_name: String, fields: List(FieldDefinition))
}

/// `*Relationships` type: single variant, same name as the type, labelled fields only.
pub type RelationshipContainerDefinition {
  RelationshipContainerDefinition(
    type_name: String,
    variants: List(VariantWithFields),
  )
}

/// `*Attributes` edge payload: single variant, same name as the type, labelled fields only.
pub type RelationshipEdgeAttributesDefinition {
  RelationshipEdgeAttributesDefinition(
    type_name: String,
    variants: List(VariantWithFields),
  )
}

/// Enum-like: every variant has no payloads; at least one variant.
pub type ScalarTypeDefinition {
  ScalarTypeDefinition(type_name: String, variant_names: List(String))
}

/// Public function that returns `Query` (annotation or trailing `Query(...)`); parameters must be typed.
pub type QuerySpecDefinition {
  QuerySpecDefinition(name: String, parameters: List(QueryParameter))
}

pub type QueryParameter {
  QueryParameter(label: Option(String), name: String, type_: glance.Type)
}

pub type ParseError {
  GlanceError(glance.Error)
  /// Render with [`format_parse_error`](#format_parse_error) / [`schema_diagnostics`](schema_diagnostics.html).
  UnsupportedSchema(span: Option(glance.Span), message: String)
}

/// Turn a [`ParseError`](#ParseError) into text using [`schema_diagnostics`](schema_diagnostics.html) (line + caret layout).
pub fn format_parse_error(source: String, error: ParseError) -> String {
  case error {
    GlanceError(e) -> glance_armstrong.format_glance_parse_error(source, e)
    UnsupportedSchema(None, message) ->
      glance_armstrong.format_diagnostic_without_span(message)
    UnsupportedSchema(Some(span), message) ->
      glance_armstrong.format_source_diagnostic(source, span, message)
  }
}

/// Parse a module **only** if every public custom type and public function fits the hippo-style rules.
pub fn parse_module(source: String) -> Result(SchemaDefinition, ParseError) {
  case glance.module(source) {
    Ok(parsed) -> build_schema_strict(parsed)
    Error(e) -> Error(GlanceError(e))
  }
}

fn build_schema_strict(
  parsed: glance.Module,
) -> Result(SchemaDefinition, ParseError) {
  // Glance prepends each definition, so `custom_types` / `functions` are reverse
  // source order. Walk them reversed so the first error matches top-to-bottom
  // in the file.
  let custom_types_ordered = list.reverse(parsed.custom_types)
  let functions_ordered = list.reverse(parsed.functions)
  use buckets <- result.try(
    list.try_fold(custom_types_ordered, initial_buckets(), fn(acc, def) {
      case def {
        glance.Definition(_, ct) -> insert_custom_type_strict(acc, ct)
      }
    }),
  )
  use _ <- result.try(validate_identity_types_linked_to_entities(
    buckets.entities,
    buckets.identities,
  ))
  use queries <- result.try(extract_query_specs_strict(functions_ordered))
  Ok(SchemaDefinition(
    entities: list.reverse(buckets.entities),
    identities: list.reverse(buckets.identities),
    relationship_containers: list.reverse(buckets.relationship_containers),
    relationship_edge_attributes: list.reverse(
      buckets.relationship_edge_attributes,
    ),
    scalars: list.reverse(buckets.scalars),
    queries: queries,
  ))
}

type Buckets {
  Buckets(
    entities: List(EntityDefinition),
    identities: List(IdentityTypeDefinition),
    relationship_containers: List(RelationshipContainerDefinition),
    relationship_edge_attributes: List(RelationshipEdgeAttributesDefinition),
    scalars: List(ScalarTypeDefinition),
  )
}

fn initial_buckets() -> Buckets {
  Buckets([], [], [], [], [])
}

fn validate_identity_types_linked_to_entities(
  entities: List(EntityDefinition),
  identities: List(IdentityTypeDefinition),
) -> Result(Nil, ParseError) {
  let referenced =
    entities
    |> list.map(fn(e) { e.identity_type_name })
  use _ <- result.try(
    list.try_each(over: identities, with: fn(id) {
      case list.any(referenced, fn(r) { r == id.type_name }) {
        True -> Ok(Nil)
        False ->
          Error(UnsupportedSchema(
            None,
            "*Identities type "
              <> id.type_name
              <> " must be the `identities` field on a public entity in this module (or use a `*Scalar` enum for standalone sum types without an entity)",
          ))
      }
    }),
  )
  list.try_each(over: entities, with: fn(entity) {
    case
      list.any(identities, fn(id) { id.type_name == entity.identity_type_name })
    {
      True -> Ok(Nil)
      False ->
        Error(UnsupportedSchema(
          None,
          "entity "
            <> entity.type_name
            <> " references "
            <> entity.identity_type_name
            <> ", but that public *Identities type is not defined in this module",
        ))
    }
  })
}

fn insert_custom_type_strict(
  acc: Buckets,
  ct: glance.CustomType,
) -> Result(Buckets, ParseError) {
  case ct.publicity {
    glance.Private -> Ok(acc)
    glance.Public ->
      case classify_strict(ct) {
        Ok(ScalarBucket(s)) -> Ok(Buckets(..acc, scalars: [s, ..acc.scalars]))
        Ok(IdentitiesBucket(i)) ->
          Ok(Buckets(..acc, identities: [i, ..acc.identities]))
        Ok(EntityBucket(e)) -> Ok(Buckets(..acc, entities: [e, ..acc.entities]))
        Ok(RelationshipContainerBucket(r)) ->
          Ok(
            Buckets(..acc, relationship_containers: [
              r,
              ..acc.relationship_containers
            ]),
          )
        Ok(EdgeAttributesBucket(a)) ->
          Ok(
            Buckets(..acc, relationship_edge_attributes: [
              a,
              ..acc.relationship_edge_attributes
            ]),
          )
        Error(e) -> Error(e)
      }
  }
}

type Classified {
  ScalarBucket(ScalarTypeDefinition)
  IdentitiesBucket(IdentityTypeDefinition)
  EntityBucket(EntityDefinition)
  RelationshipContainerBucket(RelationshipContainerDefinition)
  EdgeAttributesBucket(RelationshipEdgeAttributesDefinition)
}

fn classify_strict(ct: glance.CustomType) -> Result(Classified, ParseError) {
  use _ <- result.try(require_no_type_parameters(ct))
  use _ <- result.try(case ct.variants {
    [] ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "public type "
          <> ct.name
          <> " has no variants; add at least one (for example empty variants for a scalar enum) or make the type `private` until it is defined",
      ))
    _ -> Ok(Nil)
  })
  case try_scalar_strict(ct) {
    Some(s) ->
      case string.ends_with(ct.name, "Scalar") {
        True -> Ok(ScalarBucket(s))
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            "public scalar enum "
              <> ct.name
              <> " must end with `Scalar` (for example GenderScalar); types without that suffix that carry data on variants belong in a `*Identities` type referenced from an entity",
          ))
      }
    None ->
      case string.ends_with(ct.name, "Identities") {
        True -> identities_strict(ct)
        False ->
          case try_entity_strict(ct) {
            Ok(Some(e)) -> Ok(EntityBucket(e))
            Ok(None) ->
              case string.ends_with(ct.name, "Relationships") {
                True -> relationship_container_strict(ct)
                False ->
                  case string.ends_with(ct.name, "Attributes") {
                    True -> edge_attributes_strict(ct)
                    False ->
                      Error(UnsupportedSchema(
                        Some(ct.location),
                        "public type "
                          <> ct.name
                          <> " is not a supported squeal shape (expected entity with required identities, optional relationships, *Identities, *Relationships, *Attributes, or payload-free enum ending in `Scalar`)",
                      ))
                  }
              }
            Error(e) -> Error(e)
          }
      }
  }
}

fn require_no_type_parameters(ct: glance.CustomType) -> Result(Nil, ParseError) {
  case ct.parameters {
    [] -> Ok(Nil)
    _ ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "type "
          <> ct.name
          <> " must not have generic parameters in a squeal schema module",
      ))
  }
}

fn try_scalar_strict(ct: glance.CustomType) -> Option(ScalarTypeDefinition) {
  case ct.variants {
    [] -> None
    variants ->
      case
        list.all(variants, fn(v) {
          case v.fields {
            [] -> True
            _ -> False
          }
        })
      {
        True ->
          Some(ScalarTypeDefinition(
            ct.name,
            list.map(variants, fn(v) { v.name }),
          ))
        False -> None
      }
  }
}

fn identities_strict(ct: glance.CustomType) -> Result(Classified, ParseError) {
  case ct.variants {
    [] ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "identities type " <> ct.name <> " must declare at least one variant",
      ))
    variants -> {
      use _ <- result.try(
        list.try_fold(variants, Nil, fn(_, v) {
          case string.starts_with(v.name, "By") {
            False ->
              Error(UnsupportedSchema(
                Some(ct.location),
                "identity variant "
                  <> v.name
                  <> " in "
                  <> ct.name
                  <> " must start with `By`",
              ))
            True ->
              case variant_fields_all_labelled(v.fields) {
                False ->
                  Error(UnsupportedSchema(
                    Some(ct.location),
                    "identity variant "
                      <> v.name
                      <> " must use only labelled fields",
                  ))
                True -> Ok(Nil)
              }
          }
        }),
      )
      let defs =
        list.map(variants, fn(v) {
          IdentityVariantDefinition(v.name, variant_fields_to_defs(v.fields))
        })
      Ok(IdentitiesBucket(IdentityTypeDefinition(ct.name, defs)))
    }
  }
}

fn try_entity_strict(
  ct: glance.CustomType,
) -> Result(Option(EntityDefinition), ParseError) {
  case ct.variants {
    [glance.Variant(vname, vfields, _)] -> {
      case vname == ct.name {
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            "entity "
              <> ct.name
              <> " must use a variant constructor named `"
              <> ct.name
              <> "` (found `"
              <> vname
              <> "`); rename the variant to match the type for a table row",
          ))
        True ->
          case variant_fields_all_labelled(vfields) {
            False ->
              Error(UnsupportedSchema(
                Some(ct.location),
                "entity "
                  <> ct.name
                  <> " must use only labelled fields on its record variant",
              ))
            True ->
              case find_labelled_field(vfields, "identities") {
                None ->
                  case
                    string.ends_with(ct.name, "Attributes")
                    || string.ends_with(ct.name, "Relationships")
                  {
                    True -> Ok(None)
                    False ->
                      Error(UnsupportedSchema(
                        Some(ct.location),
                        ct.name
                          <> " has a record variant named like the type but no `identities` field; add `identities` pointing at a `*Identities` type, or use only empty variants for a scalar enum",
                      ))
                  }
                Some(#(_, id_type)) ->
                  case type_named_type_name(id_type) {
                    None ->
                      Error(UnsupportedSchema(
                        Some(ct.location),
                        "entity "
                          <> ct.name
                          <> " identities field must be a simple type name",
                      ))
                    Some(id_name) ->
                      case string.ends_with(id_name, "Identities") {
                        False ->
                          Error(UnsupportedSchema(
                            Some(ct.location),
                            "entity "
                              <> ct.name
                              <> " identities field must reference a *Identities type",
                          ))
                        True ->
                          case find_labelled_field(vfields, "relationships") {
                            None -> {
                              let fields = variant_fields_to_defs(vfields)
                              Ok(
                                Some(EntityDefinition(
                                  ct.name,
                                  vname,
                                  fields,
                                  id_name,
                                )),
                              )
                            }
                            Some(#(_, rel_type)) ->
                              case type_named_type_name(rel_type) {
                                None ->
                                  Error(UnsupportedSchema(
                                    Some(ct.location),
                                    "entity "
                                      <> ct.name
                                      <> " relationships field must be a simple type name",
                                  ))
                                Some(rel_name) ->
                                  case
                                    string.ends_with(rel_name, "Relationships")
                                  {
                                    False ->
                                      Error(UnsupportedSchema(
                                        Some(ct.location),
                                        "entity "
                                          <> ct.name
                                          <> " relationships field must reference a *Relationships type",
                                      ))
                                    True -> {
                                      let fields =
                                        variant_fields_to_defs(vfields)
                                      Ok(
                                        Some(EntityDefinition(
                                          ct.name,
                                          vname,
                                          fields,
                                          id_name,
                                        )),
                                      )
                                    }
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
    }
    _ -> Ok(None)
  }
}

fn relationship_container_strict(
  ct: glance.CustomType,
) -> Result(Classified, ParseError) {
  case ct.variants {
    [glance.Variant(vname, vfields, _)] ->
      case vname == ct.name {
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            "*Relationships type "
              <> ct.name
              <> " must use a single variant of the same name",
          ))
        True ->
          case variant_fields_all_labelled(vfields) {
            False ->
              Error(UnsupportedSchema(
                Some(ct.location),
                "*Relationships " <> ct.name <> " must use only labelled fields",
              ))
            True -> {
              let v = VariantWithFields(vname, variant_fields_to_defs(vfields))
              Ok(
                RelationshipContainerBucket(
                  RelationshipContainerDefinition(ct.name, [v]),
                ),
              )
            }
          }
      }
    _ ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "*Relationships type " <> ct.name <> " must have exactly one variant",
      ))
  }
}

fn edge_attributes_strict(
  ct: glance.CustomType,
) -> Result(Classified, ParseError) {
  case ct.variants {
    [glance.Variant(vname, vfields, _)] ->
      case vname == ct.name {
        False ->
          Error(UnsupportedSchema(
            Some(ct.location),
            "*Attributes type "
              <> ct.name
              <> " must use a single variant of the same name",
          ))
        True ->
          case variant_fields_all_labelled(vfields) {
            False ->
              Error(UnsupportedSchema(
                Some(ct.location),
                "*Attributes " <> ct.name <> " must use only labelled fields",
              ))
            True -> {
              let v = VariantWithFields(vname, variant_fields_to_defs(vfields))
              Ok(
                EdgeAttributesBucket(
                  RelationshipEdgeAttributesDefinition(ct.name, [v]),
                ),
              )
            }
          }
      }
    _ ->
      Error(UnsupportedSchema(
        Some(ct.location),
        "*Attributes type " <> ct.name <> " must have exactly one variant",
      ))
  }
}

fn variant_fields_all_labelled(fields: List(glance.VariantField)) -> Bool {
  list.all(fields, fn(f) {
    case f {
      glance.LabelledVariantField(_, _) -> True
      glance.UnlabelledVariantField(_) -> False
    }
  })
}

fn find_labelled_field(
  fields: List(glance.VariantField),
  want: String,
) -> Option(#(String, glance.Type)) {
  case fields {
    [] -> None
    [glance.LabelledVariantField(t, label), ..rest] ->
      case label == want {
        True -> Some(#(label, t))
        False -> find_labelled_field(rest, want)
      }
    [glance.UnlabelledVariantField(_), ..rest] ->
      find_labelled_field(rest, want)
  }
}

fn type_named_type_name(t: glance.Type) -> Option(String) {
  case t {
    glance.NamedType(_, name, _, _) -> Some(name)
    _ -> None
  }
}

fn variant_fields_to_defs(
  fields: List(glance.VariantField),
) -> List(FieldDefinition) {
  list.reverse(fields_to_defs_loop(fields, 1, []))
}

fn fields_to_defs_loop(
  fields: List(glance.VariantField),
  index: Int,
  acc: List(FieldDefinition),
) -> List(FieldDefinition) {
  case fields {
    [] -> acc
    [field, ..rest] -> {
      let pair = case field {
        glance.LabelledVariantField(item, label) -> FieldDefinition(label, item)
        glance.UnlabelledVariantField(item) ->
          FieldDefinition("field_" <> int.to_string(index), item)
      }
      fields_to_defs_loop(rest, index + 1, [pair, ..acc])
    }
  }
}

fn extract_query_specs_strict(
  functions: List(glance.Definition(glance.Function)),
) -> Result(List(QuerySpecDefinition), ParseError) {
  list.try_fold(functions, [], fn(acc, def) {
    case def {
      glance.Definition(_, f) ->
        case f.publicity {
          glance.Private -> Ok(acc)
          glance.Public ->
            case function_is_query_spec(f) {
              False ->
                Error(UnsupportedSchema(
                  Some(f.location),
                  "public function "
                    <> f.name
                    <> " must return a Query (annotation or trailing Query(...))",
                ))
              True ->
                case query_spec_from_function_strict(f) {
                  Ok(spec) -> Ok([spec, ..acc])
                  Error(e) -> Error(e)
                }
            }
        }
    }
  })
  |> result.map(list.reverse)
}

fn query_spec_from_function_strict(
  f: glance.Function,
) -> Result(QuerySpecDefinition, ParseError) {
  list.try_fold(f.parameters, [], fn(acc, p) {
    case p.type_ {
      None ->
        Error(UnsupportedSchema(
          Some(f.location),
          "public query " <> f.name <> " parameters must have type annotations",
        ))
      Some(t) ->
        Ok([QueryParameter(p.label, assignment_name_string(p.name), t), ..acc])
    }
  })
  |> result.map(fn(params) { QuerySpecDefinition(f.name, list.reverse(params)) })
}

fn function_is_query_spec(f: glance.Function) -> Bool {
  case f.return {
    Some(t) -> type_is_query(t)
    None -> statements_return_query(f.body)
  }
}

fn type_is_query(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "Query", _, _) -> True
    _ -> False
  }
}

fn statements_return_query(body: List(glance.Statement)) -> Bool {
  case list.last(body) {
    Error(Nil) -> False
    Ok(stmt) ->
      case stmt {
        glance.Expression(e) -> expression_is_query_in_tail(e)
        _ -> False
      }
  }
}

fn expression_is_query_in_tail(expr: glance.Expression) -> Bool {
  case expr {
    glance.Call(_, callee, _) -> callee_is_query(callee)
    glance.Block(_, stmts) -> statements_return_query(stmts)
    _ -> False
  }
}

fn callee_is_query(expr: glance.Expression) -> Bool {
  case expression_callee_name(expr) {
    Ok("Query") -> True
    _ -> False
  }
}

fn expression_callee_name(expr: glance.Expression) -> Result(String, Nil) {
  case expr {
    glance.Variable(_, name) -> Ok(name)
    glance.FieldAccess(_, _inner, label) -> Ok(label)
    _ -> Error(Nil)
  }
}

fn assignment_name_string(name: glance.AssignmentName) -> String {
  case name {
    glance.Named(s) -> s
    glance.Discarded(s) -> s
  }
}
