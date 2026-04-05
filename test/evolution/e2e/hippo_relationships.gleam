import case_studies/hippo_db/api as hippo_api
import case_studies/hippo_db/cmd as hippo_cmd
import case_studies/hippo_schema.{Female, Male}
import gleam/list
import gleam/option.{Some}
import gleam/order
import gleam/string
import gleam/time/calendar.{Date, January}
import sqlight

/// End-to-end checks for [`hippo_schema.old_hippos_owner_emails`](test/case_studies/hippo_schema.gleam)
/// and [`hippo_schema.hippos_by_gender`](test/case_studies/hippo_schema.gleam): owner `BelongsTo` join,
/// age filter, gender filter, and name ordering.
pub fn hippo_relationship_queries_e2e_test() {
  let assert Ok(conn) = sqlight.open(":memory:")
  let assert Ok(Nil) = hippo_api.migrate(conn)

  let dob_old = Date(1975, January, 1)
  let dob_young = Date(2022, January, 1)
  let assert Ok(Nil) =
    hippo_api.execute_hippo_cmds(conn, [
      hippo_cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Oldie",
        date_of_birth: dob_old,
        gender: Some(Male),
      ),
    ])
  let assert Ok(Nil) =
    hippo_api.execute_hippo_cmds(conn, [
      hippo_cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Youngin",
        date_of_birth: dob_young,
        gender: Some(Female),
      ),
    ])
  let assert Ok(Nil) =
    hippo_api.execute_hippo_cmds(conn, [
      hippo_cmd.UpsertHippoByNameAndDateOfBirth(
        name: "Zebra",
        date_of_birth: dob_old,
        gender: Some(Male),
      ),
    ])

  let assert Ok(old_rows) =
    hippo_api.query_old_hippos_owner_emails(conn, min_age: 30)
  let old_names =
    list.map(old_rows, fn(row) {
      let #(h, _) = row
      let assert Some(n) = h.name
      n
    })
  let assert True = list.contains(old_names, "Oldie")
  let assert True = list.contains(old_names, "Zebra")
  let assert False = list.contains(old_names, "Youngin")

  let assert Ok(by_gender) =
    hippo_api.query_hippos_by_gender(conn, gender_to_match: Male)
  let male_names =
    list.map(by_gender, fn(row) {
      let #(h, _) = row
      let assert Some(n) = h.name
      n
    })
  let assert True = list.contains(male_names, "Oldie")
  let assert True = list.contains(male_names, "Zebra")
  let assert False = list.contains(male_names, "Youngin")

  let expected_order = list.sort(male_names, order.reverse(string.compare))
  let assert True = male_names == expected_order

  let assert Ok(Nil) = sqlight.close(conn)
}
