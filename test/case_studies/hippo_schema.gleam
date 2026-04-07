import gleam/option
import gleam/time/calendar.{type Date}
import swil/dsl.{
  type BacklinkWith, type BelongsTo, type Mutual, age, exclude_if_missing,
  nullable,
}

/// Example schema module.
///
/// This module intentionally contains only declarative schema/query input code.
/// Generated SQL-facing output belongs in `hippo_db`.
pub type Hippo {
  Hippo(
    name: option.Option(String),
    gender: option.Option(GenderScalar),
    date_of_birth: option.Option(Date),
    identities: HippoIdentities,
    relationships: HippoRelationships,
  )
}

pub type HippoRelationships {
  HippoRelationships(
    friends: Mutual(List(Hippo), FriendshipAttributes),
    best_friend: Mutual(option.Option(Hippo), FriendshipAttributes),
    owner: BelongsTo(option.Option(Human), Nil),
  )
}

pub type FriendshipAttributes {
  FriendshipAttributes(since: option.Option(Date))
}

/// Identities define unique upsert/delete keys.
pub type HippoIdentities {
  ByNameAndDateOfBirth(name: String, date_of_birth: Date)
}

pub type Human {
  Human(
    name: option.Option(String),
    email: option.Option(String),
    hippos: List(Hippo),
    identities: HumanIdentities,
    relationships: HumanRelationships,
  )
}

// scalar types... how do we infer? no properties?
pub type GenderScalar {
  Male
  Female
}

pub type HumanRelationships {
  HumanRelationships(hippos: BacklinkWith(List(Hippo), FriendshipAttributes))
}

pub type HumanIdentities {
  ByEmail(email: String)
}

/// Query input spec for "old hippos owner emails".
pub fn query_old_hippos_owner_emails(
  hippo: Hippo,
  _magic_fields: dsl.MagicFields,
  min_age: Int,
) {
  dsl.query(hippo)
  |> dsl.shape(#(
    #("age", age(exclude_if_missing(hippo.date_of_birth))),
    #("owner_email", nullable(hippo.relationships.owner.item).email),
  ))
  |> dsl.filter_bool(age(exclude_if_missing(hippo.date_of_birth)) > min_age)
  |> dsl.order_by(age(exclude_if_missing(hippo.date_of_birth)), dsl.Desc)
}

/// Query input spec for "old hippos owner emails".
pub fn query_old_hippos_owner_names(
  hippo: Hippo,
  _magic_fields: dsl.MagicFields,
  min_age: Int,
) {
  dsl.query(hippo)
  |> dsl.shape(#(
    #("age", age(exclude_if_missing(hippo.date_of_birth))),
    #("owner_email", nullable(hippo.relationships.owner.item).email),
  ))
  |> dsl.filter_bool(age(exclude_if_missing(hippo.date_of_birth)) > min_age)
  |> dsl.order_by(age(exclude_if_missing(hippo.date_of_birth)), dsl.Desc)
}

/// Query input spec for "hippos by gender".
pub fn query_hippos_by_gender(
  hippo: Hippo,
  _magic_fields: dsl.MagicFields,
  gender_to_match: GenderScalar,
) {
  dsl.query(hippo)
  |> dsl.shape(hippo)
  |> dsl.filter_bool(exclude_if_missing(hippo.gender) == gender_to_match)
  |> dsl.order_by(hippo.name, dsl.Desc)
}
