import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Parsed view of a schema Gleam module (types + public query helpers) for codegen.
pub type SchemaDefinition {
  SchemaDefinition(
    entities: List(EntityDefinition),
    identities: List(IdentityTypeDefinition),
    /// Types named `*Relationships` holding `BelongsTo` / `Mutual` / `BacklinkWith` edges.
    relationship_containers: List(RelationshipContainerDefinition),
    /// Types named `*Attributes` (edge payloads), e.g. fields on a `Mutual(.., Attr)`.
    relationship_edge_attributes: List(RelationshipEdgeAttributesDefinition),
    scalars: List(ScalarTypeDefinition),
    /// Single-variant records that are not entities (no `identities` field), e.g. nested rows.
    struct_types: List(StructTypeDefinition),
    /// Custom types with two or more variants (sum types outside identities/scalars).
    union_types: List(UnionTypeDefinition),
    /// Custom types with no variants (`pub type T` opaque-style in the AST).
    opaque_types: List(OpaqueTypeDefinition),
    queries: List(QuerySpecDefinition),
  )
}

/// Aggregate root: single record variant and an `identities: …Identities` field.
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

/// Custom type whose name ends with `Identities` (convention).
pub type IdentityTypeDefinition {
  IdentityTypeDefinition(
    type_name: String,
    variants: List(IdentityVariantDefinition),
  )
}

pub type IdentityVariantDefinition {
  IdentityVariantDefinition(
    variant_name: String,
    fields: List(FieldDefinition),
  )
}

pub type VariantWithFields {
  VariantWithFields(variant_name: String, fields: List(FieldDefinition))
}

/// Container for outgoing edges on an entity (`HippoRelationships`, …).
pub type RelationshipContainerDefinition {
  RelationshipContainerDefinition(
    type_name: String,
    type_parameters: List(String),
    variants: List(VariantWithFields),
  )
}

/// Payload type carried on a relationship edge (`FriendshipAttributes`, …).
pub type RelationshipEdgeAttributesDefinition {
  RelationshipEdgeAttributesDefinition(
    type_name: String,
    type_parameters: List(String),
    variants: List(VariantWithFields),
  )
}

/// Enum-like type: every variant has no payloads.
pub type ScalarTypeDefinition {
  ScalarTypeDefinition(type_name: String, variant_names: List(String))
}

/// Single-variant product type (not classified as entity or edge bundle).
pub type StructTypeDefinition {
  StructTypeDefinition(
    type_name: String,
    type_parameters: List(String),
    variant_name: String,
    fields: List(FieldDefinition),
  )
}

/// Multi-variant custom type that is not an identity bundle or scalar enum.
pub type UnionTypeDefinition {
  UnionTypeDefinition(
    type_name: String,
    type_parameters: List(String),
    variants: List(VariantWithFields),
  )
}

pub type OpaqueTypeDefinition {
  OpaqueTypeDefinition(type_name: String, type_parameters: List(String))
}

/// Public function that returns a `Query` (annotation or trailing `Query(...)`).
pub type QuerySpecDefinition {
  QuerySpecDefinition(name: String, parameters: List(QueryParameter))
}

pub type QueryParameter {
  QueryParameter(label: Option(String), name: String, type_: glance.Type)
}

pub type ParseError {
  GlanceError(glance.Error)
}

/// Parse a Gleam module source into a [`SchemaDefinition`](#SchemaDefinition).
pub fn parse_module(source: String) -> Result(SchemaDefinition, ParseError) {
  case glance.module(source) {
    Ok(parsed) -> Ok(build_schema(parsed))
    Error(e) -> Error(GlanceError(e))
  }
}

fn build_schema(parsed: glance.Module) -> SchemaDefinition {
  let classified =
    list.fold(parsed.custom_types, initial_buckets(), fn(acc, def) {
      case def {
        glance.Definition(_, ct) -> insert_custom_type(acc, ct)
      }
    })
  let queries = extract_query_specs(parsed.functions)
  SchemaDefinition(
    entities: list.reverse(classified.entities),
    identities: list.reverse(classified.identities),
    relationship_containers: list.reverse(classified.relationship_containers),
    relationship_edge_attributes: list.reverse(
      classified.relationship_edge_attributes,
    ),
    scalars: list.reverse(classified.scalars),
    struct_types: list.reverse(classified.struct_types),
    union_types: list.reverse(classified.union_types),
    opaque_types: list.reverse(classified.opaque_types),
    queries: queries,
  )
}

type Buckets {
  Buckets(
    entities: List(EntityDefinition),
    identities: List(IdentityTypeDefinition),
    relationship_containers: List(RelationshipContainerDefinition),
    relationship_edge_attributes: List(RelationshipEdgeAttributesDefinition),
    scalars: List(ScalarTypeDefinition),
    struct_types: List(StructTypeDefinition),
    union_types: List(UnionTypeDefinition),
    opaque_types: List(OpaqueTypeDefinition),
  )
}

fn initial_buckets() -> Buckets {
  Buckets([], [], [], [], [], [], [], [])
}

fn insert_custom_type(acc: Buckets, ct: glance.CustomType) -> Buckets {
  case classify_custom_type(ct) {
    ScalarBucket(s) ->
      Buckets(..acc, scalars: [s, ..acc.scalars])
    IdentitiesBucket(i) ->
      Buckets(..acc, identities: [i, ..acc.identities])
    EntityBucket(e) ->
      Buckets(..acc, entities: [e, ..acc.entities])
    RelationshipContainerBucket(r) ->
      Buckets(..acc, relationship_containers: [
        r,
        ..acc.relationship_containers
      ])
    EdgeAttributesBucket(a) ->
      Buckets(..acc, relationship_edge_attributes: [
        a,
        ..acc.relationship_edge_attributes
      ])
    StructBucket(st) ->
      Buckets(..acc, struct_types: [st, ..acc.struct_types])
    UnionBucket(u) ->
      Buckets(..acc, union_types: [u, ..acc.union_types])
    OpaqueBucket(o) ->
      Buckets(..acc, opaque_types: [o, ..acc.opaque_types])
  }
}

type Classified {
  ScalarBucket(ScalarTypeDefinition)
  IdentitiesBucket(IdentityTypeDefinition)
  EntityBucket(EntityDefinition)
  RelationshipContainerBucket(RelationshipContainerDefinition)
  EdgeAttributesBucket(RelationshipEdgeAttributesDefinition)
  StructBucket(StructTypeDefinition)
  UnionBucket(UnionTypeDefinition)
  OpaqueBucket(OpaqueTypeDefinition)
}

fn classify_custom_type(ct: glance.CustomType) -> Classified {
  case try_scalar(ct) {
    Some(s) -> ScalarBucket(s)
    None ->
      case string.ends_with(ct.name, "Identities") {
        True -> IdentitiesBucket(identity_type_from(ct))
        False ->
          case try_entity(ct) {
            Some(e) -> EntityBucket(e)
            None ->
              case string.ends_with(ct.name, "Relationships") {
                True ->
                  RelationshipContainerBucket(relationship_container_from(ct))
                False ->
                  case string.ends_with(ct.name, "Attributes") {
                    True ->
                      EdgeAttributesBucket(edge_attributes_from(ct))
                    False -> classify_remaining_shape(ct)
                  }
              }
          }
      }
  }
}

fn classify_remaining_shape(ct: glance.CustomType) -> Classified {
  case ct.variants {
    [] -> OpaqueBucket(OpaqueTypeDefinition(ct.name, ct.parameters))
    [v] ->
      StructBucket(StructTypeDefinition(
        ct.name,
        ct.parameters,
        v.name,
        variant_fields_to_defs(v.fields),
      ))
    vs -> UnionBucket(union_from_variants(ct, vs))
  }
}

fn union_from_variants(
  ct: glance.CustomType,
  variants: List(glance.Variant),
) -> UnionTypeDefinition {
  let mapped =
    list.map(variants, fn(v) {
      VariantWithFields(v.name, variant_fields_to_defs(v.fields))
    })
  UnionTypeDefinition(ct.name, ct.parameters, mapped)
}

fn relationship_container_from(
  ct: glance.CustomType,
) -> RelationshipContainerDefinition {
  RelationshipContainerDefinition(
    ct.name,
    ct.parameters,
    variants_with_fields(ct),
  )
}

fn edge_attributes_from(
  ct: glance.CustomType,
) -> RelationshipEdgeAttributesDefinition {
  RelationshipEdgeAttributesDefinition(
    ct.name,
    ct.parameters,
    variants_with_fields(ct),
  )
}

fn variants_with_fields(ct: glance.CustomType) -> List(VariantWithFields) {
  list.map(ct.variants, fn(v) {
    VariantWithFields(v.name, variant_fields_to_defs(v.fields))
  })
}

fn try_scalar(ct: glance.CustomType) -> Option(ScalarTypeDefinition) {
  case
    list.all(ct.variants, fn(v) {
      case v.fields {
        [] -> True
        _ -> False
      }
    })
  {
    True ->
      Some(ScalarTypeDefinition(
        ct.name,
        list.map(ct.variants, fn(v) { v.name }),
      ))
    False -> None
  }
}

fn identity_type_from(ct: glance.CustomType) -> IdentityTypeDefinition {
  let variants =
    list.map(ct.variants, fn(v) {
      IdentityVariantDefinition(v.name, variant_fields_to_defs(v.fields))
    })
  IdentityTypeDefinition(ct.name, variants)
}

fn try_entity(ct: glance.CustomType) -> Option(EntityDefinition) {
  case ct.variants {
    [glance.Variant(vname, vfields, _)] ->
      case find_labelled_field(vfields, "identities") {
        Some(#(_, id_type)) ->
          case type_named_type_name(id_type) {
            Some(id_name) -> {
              let fields = variant_fields_to_defs(vfields)
              Some(EntityDefinition(ct.name, vname, fields, id_name))
            }
            None -> None
          }
        None -> None
      }
    _ -> None
  }
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

fn variant_fields_to_defs(fields: List(glance.VariantField)) -> List(FieldDefinition) {
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
        glance.LabelledVariantField(item, label) ->
          FieldDefinition(label, item)
        glance.UnlabelledVariantField(item) ->
          FieldDefinition("field_" <> int.to_string(index), item)
      }
      fields_to_defs_loop(rest, index + 1, [pair, ..acc])
    }
  }
}

fn extract_query_specs(
  functions: List(glance.Definition(glance.Function)),
) -> List(QuerySpecDefinition) {
  list.filter_map(functions, fn(def) {
    case def {
      glance.Definition(_, f) -> {
        case f.publicity {
          glance.Public ->
            case function_is_query_spec(f) {
              True -> Ok(query_spec_from_function(f))
              False -> Error(Nil)
            }
          glance.Private -> Error(Nil)
        }
      }
    }
  })
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

fn query_spec_from_function(f: glance.Function) -> QuerySpecDefinition {
  let params =
    list.filter_map(f.parameters, fn(p) {
      case p.type_ {
        Some(t) ->
          Ok(QueryParameter(p.label, assignment_name_string(p.name), t))
        None -> Error(Nil)
      }
    })
  QuerySpecDefinition(f.name, params)
}

fn assignment_name_string(name: glance.AssignmentName) -> String {
  case name {
    glance.Named(s) -> s
    glance.Discarded(s) -> s
  }
}
