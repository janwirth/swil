import glance
import gleam/option.{type Option}
import dsl/dsl as dsl
/// Parsed from a full schema module that may contain entities, identities, relationships,
/// edge attributes, scalar types, and public query functions.
///
/// Example source:
/// ```gleam
/// pub type Fruit {
///   Fruit(name: Option(String), identities: FruitIdentities)
/// }
/// pub type FruitIdentities {
///   ByName(name: String)
/// }
/// pub fn query_cheap_fruit(
///   fruit: Fruit,
///   magic: dsl.MagicFields,
///   max_price: Float,
/// ) {
///   dsl.query(fruit)
///   |> dsl.shape(fruit)
///   |> dsl.filter(dsl.exclude_if_missing(fruit.price) <. max_price)
///   |> dsl.order(dsl.order_by(fruit.price, dsl.Asc))
/// }
/// ```
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

/// Parsed from a public entity custom type with one record variant whose constructor
/// name equals the type name and which includes `identities: *Identities`.
///
/// Example source:
/// ```gleam
/// pub type Human {
///   Human(
///     name: Option(String),
///     age: Option(Int),
///     identities: HumanIdentities,
///   )
/// }
/// ```
pub type EntityDefinition {
  EntityDefinition(
    type_name: String,
    variant_name: String,
    fields: List(FieldDefinition),
    identity_type_name: String,
  )
}

/// Parsed from one labelled field inside a variant.
///
/// Example source field:
/// ```gleam
/// age: Option(Int)
/// ```
pub type FieldDefinition {
  FieldDefinition(label: String, type_: glance.Type)
}

/// Parsed from a `*Identities` type whose variants start with `By`.
///
/// Example source:
/// ```gleam
/// pub type HumanIdentities {
///   ByEmail(email: String)
///   ByNameAndBirthDate(name: String, birth_date: Date)
/// }
/// ```
pub type IdentityTypeDefinition {
  IdentityTypeDefinition(
    type_name: String,
    variants: List(IdentityVariantDefinition),
  )
}

/// Parsed from one `By...` variant in an identities type.
///
/// Example source:
/// ```gleam
/// ByEmail(email: String)
/// ```
pub type IdentityVariantDefinition {
  IdentityVariantDefinition(variant_name: String, fields: List(FieldDefinition))
}

/// Parsed from the single variant inside `*Relationships` / `*Attributes` containers.
///
/// Example source:
/// ```gleam
/// HippoRelationships(owner: Option(Human))
/// ```
pub type VariantWithFields {
  VariantWithFields(variant_name: String, fields: List(FieldDefinition))
}

/// Parsed from a `*Relationships` type with exactly one variant of the same name.
///
/// Example source:
/// ```gleam
/// pub type HippoRelationships {
///   HippoRelationships(owner: Option(Human))
/// }
/// ```
pub type RelationshipContainerDefinition {
  RelationshipContainerDefinition(
    type_name: String,
    variants: List(VariantWithFields),
  )
}

/// Parsed from a `*Attributes` type with exactly one variant of the same name.
///
/// Example source:
/// ```gleam
/// pub type OwnershipAttributes {
///   OwnershipAttributes(since: Option(Date), note: Option(String))
/// }
/// ```
pub type RelationshipEdgeAttributesDefinition {
  RelationshipEdgeAttributesDefinition(
    type_name: String,
    variants: List(VariantWithFields),
  )
}

/// Parsed from a type whose name ends with `Scalar`.
///
/// Example sources:
/// ```gleam
/// pub type GenderScalar {
///   Male
///   Female
/// }
///
/// pub type MoneyScalar {
///   MoneyScalar(amount: Float, currency: String)
/// }
/// ```
pub type ScalarTypeDefinition {
  ScalarTypeDefinition(
    type_name: String,
    variant_names: List(String),
    enum_only: Bool,
  )
}

/// Parsed from one public `query_*` function.
///
/// Example source:
/// ```gleam
/// pub fn query_cheap_fruit(
///   fruit: Fruit,
///   magic: dsl.MagicFields,
///   max_price: Float,
/// ) { ... }
/// ```
pub type QuerySpecDefinition {
  QuerySpecDefinition(
    name: String,
    parameters: List(QueryParameter),
    query: Query,
  )
}

pub type Query {
  Query(shape: Shape, filter: Option(Filter), order: Order)
}

/// Expression AST for query shape/filter/order.
///
/// This is introduced incrementally and will replace stringly field references in
/// `Shape`, `Filter`, and `Order` once parser/codegen migration is complete.
pub type Expr {
  Field(path: List(String))
  Param(name: String)
  Call(func: ExprFn, args: List(Expr))
}

pub type ExprFn {
  ExcludeIfMissingFn
  NullableFn
  AgeFn
}

pub type Order {
  UpdatedAtDesc
  CustomOrder(expr: Expr, direction: dsl.Direction)
}

/// Shape of the query result.
///
/// Example source:
/// ```gleam
/// query_cheap_fruit(fruit, magic, max_price)
/// dsl.query(fruit)
/// |> dsl.shape([fruit.price, fruit.weight])
/// gives back CheapFruit({price: Float, weight: Float})
/// ```
pub type Shape {
  NoneOrBase
  Subset(selection: List(ShapeItem))
}

pub type ShapeItem {
  ShapeField(alias: Option(String), expr: Expr)
}

pub type SelectionPath {
  // can be a path on the root type or its relationships
  SelectionPath(fields: List(String))
}

pub type Filter {
  NoFilter
  Predicate(pred: Pred)
}

pub type Pred {
  Compare(left: Expr, operator: Operator, right: Expr, missing_behavior: MissingBehavior)
  And(items: List(Pred))
  Or(items: List(Pred))
  Not(item: Pred)
}

pub type MissingBehavior {
  ExcludeIfMissing
  Nullable
}

pub type Operator {
  Lt
  Eq
  Gt
  Ne
  Le
  Ge
}


// Parsed from the recognized tail shape of a public query function.
//
// Example source pattern:
// ```gleam
// dsl.query(fruit)
// |> dsl.shape(fruit)
// |> dsl.filter(dsl.exclude_if_missing(fruit.price) <. max_price)
// |> dsl.order(dsl.order_by(fruit.price, dsl.Asc))
// ```
// pub type QueryCodegen {
//   Unsupported
//   LtMissingFieldAsc(
//     column: String,
//     threshold_param: String,
//     shape_param: String,
//   )
//   EqMissingFieldOrder(
//     filter_column: String,
//     match_param: String,
//     shape_param: String,
//     order_column: String,
//     order_desc: Bool,
//   )
// }

/// Parsed from one typed parameter in a public query function signature.
///
/// Example source:
/// ```gleam
/// max_price: Float
/// ```
pub type QueryParameter {
  QueryParameter(label: Option(String), name: String, type_: glance.Type)
}

/// Parsed/normalized target shape for public `query_*` parameters:
/// `(entity, dsl.MagicFields, simple)`.
///
/// Example source:
/// ```gleam
/// pub fn query_cheap_fruit(
///   fruit: Fruit,
///   magic: dsl.MagicFields,
///   max_price: Float,
/// ) { ... }
/// ```
pub type QueryFunctionParameters {
  QueryFunctionParameters(
    entity: QueryEntityParameter,
    magic_fields: QueryMagicFieldsParameter,
    simple: QuerySimpleParameter,
  )
}

/// Parsed from parameter 1 in the query contract.
///
/// Example source:
/// ```gleam
/// fruit: Fruit
/// ```
pub type QueryEntityParameter {
  QueryEntityParameter(name: String, type_name: String)
}

/// Parsed from parameter 2 in the query contract.
///
/// Example source:
/// ```gleam
/// magic: dsl.MagicFields
/// ```
pub type QueryMagicFieldsParameter {
  QueryMagicFieldsParameter(name: String)
}

/// Parsed from parameter 3 in the query contract.
///
/// Example source:
/// ```gleam
/// max_price: Float
/// ```
pub type QuerySimpleParameter {
  QuerySimpleParameter(name: String, type_: QuerySimpleType)
}

/// Parsed from the simple bind type in parameter 3.
///
/// Example source types:
/// ```gleam
/// Int
/// Float
/// Bool
/// String
/// ```
pub type QuerySimpleType {
  QuerySimpleInt
  QuerySimpleFloat
  QuerySimpleBool
  QuerySimpleString
}

/// Parsed error emitted while validating schema source shape.
///
/// Example source that fails:
/// ```gleam
/// pub type Fruit {
///   NotFruit(name: Option(String), identities: FruitIdentities)
/// }
/// ```
pub type ParseError {
  GlanceError(glance.Error)
  UnsupportedSchema(span: Option(glance.Span), message: String)
}
