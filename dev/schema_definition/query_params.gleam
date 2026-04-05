//// Intended shape of parameters on every public `query_*` schema function (query generation simplification).
//// Validation against [`QueryFunctionParameters`](#QueryFunctionParameters) is wired incrementally; consumers
//// can already pattern-match these types when inspecting or generating APIs.

/// Mandatory three slots, in source order, after the naming/prefix rules for `query_*` functions.
pub type QueryFunctionParameters {
  QueryFunctionParameters(
    /// Entity row the query operates on (must be a public entity type from the same module).
    entity: QueryEntityParameter,
    /// Generated row metadata (`dsl.MagicFields` at the type level).
    magic_fields: QueryMagicFieldsParameter,
    /// Single user bind (filter threshold, limit, flag, …): one simple type only.
    simple: QuerySimpleParameter,
  )
}

/// Slot 1 — recognized entity: binding name plus the entity’s type name as declared on `pub type`.
pub type QueryEntityParameter {
  QueryEntityParameter(name: String, type_name: String)
}

/// Slot 2 — magic row fields supplied by codegen (`id`, timestamps, soft delete).
/// If a query does not mention these, the author should still take `dsl.MagicFields` and use discard
/// patterns for each field at the binding site (`id: _`, `created_at: _`, `updated_at: _`,
/// `deleted_at: _`) so unused slots stay explicit.
pub type QueryMagicFieldsParameter {
  QueryMagicFieldsParameter(name: String)
}

/// Slot 3 — exactly one parameter whose type is a [`QuerySimpleType`](#QuerySimpleType).
pub type QuerySimpleParameter {
  QuerySimpleParameter(name: String, type_: QuerySimpleType)
}

/// Allowed “simple” types for the third parameter (extends later: dates, scalar enums, etc.).
pub type QuerySimpleType {
  QuerySimpleInt
  QuerySimpleFloat
  QuerySimpleBool
  QuerySimpleString
}
