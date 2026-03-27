import case_studies/hippo_db/api as hippo_api
import case_studies/hippo_db/relationship_queries as rel
import case_studies/hippo_schema.{ByEmail, Female, Male}
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/string
import gleam/time/calendar.{Date, January}
import sqlight
import gleam/io

/// End-to-end checks for [`hippo_schema.old_hippos_owner_emails`](src/case_studies/hippo_schema.gleam)
/// and [`hippo_schema.hippos_by_gender`](src/case_studies/hippo_schema.gleam): owner `BelongsTo` join,
/// age filter, gender filter, and name ordering.
pub fn hippo_relationship_queries_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = hippo_api.migrate(conn)

  let assert Ok(#(human_row, human_magic)) =
    rel.upsert_human_by_email(conn, "keeper@example.test", Some("Pat"))
  let keeper_email = case human_row.identities {
    ByEmail(email: e) -> e
  }

  let dob_old = Date(1975, January, 1)
  let dob_young = Date(2022, January, 1)
  let assert Ok(_) =
    hippo_api.upsert_hippo_by_name_and_date_of_birth(
      conn,
      "Oldie",
      dob_old,
      Some(Male),
    )
  let assert Ok(_) =
    hippo_api.upsert_hippo_by_name_and_date_of_birth(
      conn,
      "Youngin",
      dob_young,
      Some(Female),
    )
  let assert Ok(_) =
    hippo_api.upsert_hippo_by_name_and_date_of_birth(
      conn,
      "Zebra",
      dob_old,
      Some(Male),
    )

  let assert Ok(Nil) =
    rel.set_hippo_owner_human_id(conn, "Oldie", dob_old, human_magic.id)
  let assert Ok(Nil) =
    rel.set_hippo_owner_human_id(conn, "Youngin", dob_young, human_magic.id)

  let assert Ok(old_rows) = rel.query_old_hippos_owner_emails(conn, 30)
  let old_with_email =
    list.filter(old_rows, fn(r) { r.owner_email == Some(keeper_email) })
  let assert True = list.length(old_with_email) == 1
  let assert True =
    case list.first(old_with_email) {
      Ok(r) -> r.age > 30
      Error(Nil) -> False
    }

  let assert Ok(by_gender) = rel.query_hippos_by_gender(conn, Male)
  let male_names =
    list.map(by_gender, fn(row) {
      let assert Some(n) = row.name
      n
    })
  let assert True = list.contains(male_names, "Oldie")
  let assert True = list.contains(male_names, "Zebra")
  let assert False = list.contains(male_names, "Youngin")

  let expected_order = list.sort(male_names, order.reverse(string.compare))
  let assert True = male_names == expected_order

  let assert Ok(oldie_row) =
    list.find(by_gender, fn(r) { r.name == Some("Oldie") })
  let assert Some(#(owner_h, _)) = oldie_row.owner
  let owner_mail = case owner_h.identities {
    ByEmail(email: em) -> em
  }
  let assert True = owner_mail == keeper_email

  let assert Ok(zebra_row) =
    list.find(by_gender, fn(r) { r.name == Some("Zebra") })
  let assert True = zebra_row.owner == None

  let assert Ok(Nil) = sqlight.close(conn)
}
