import swil/dsl/dsl
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/calendar.{
  type Date, Date as CalDate, month_from_int, month_to_int,
}
import gleam/time/timestamp

fn pad2(n: Int) -> String {
  let s = int.to_string(n)
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}

pub fn date_to_db_string(d: Date) -> String {
  let CalDate(year:, month:, day:) = d
  int.to_string(year) <> "-" <> pad2(month_to_int(month)) <> "-" <> pad2(day)
}

pub fn date_from_db_string(s: String) -> Date {
  case string.split(s, "-") {
    [ys, ms, ds] -> {
      let assert Ok(y) = int.parse(ys)
      let assert Ok(mi) = int.parse(ms)
      let assert Ok(d) = int.parse(ds)
      let assert Ok(month) = month_from_int(mi)
      CalDate(y, month, d)
    }
    _ -> panic as "api_help: expected YYYY-MM-DD date string"
  }
}

pub fn magic_from_db_row(
  id: Int,
  created_s: Int,
  updated_s: Int,
  deleted_raw: Option(Int),
) -> dsl.MagicFields {
  dsl.MagicFields(
    id:,
    created_at: timestamp.from_unix_seconds(created_s),
    updated_at: timestamp.from_unix_seconds(updated_s),
    deleted_at: case deleted_raw {
      Some(s) -> Some(timestamp.from_unix_seconds(s))
      None -> None
    },
  )
}

pub fn unix_seconds_now() -> Int {
  let #(s, _) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds
  s
}

pub fn opt_text_for_db(o: Option(String)) -> String {
  case o {
    Some(s) -> s
    None -> ""
  }
}

pub fn opt_float_for_db(o: Option(Float)) -> Float {
  case o {
    Some(f) -> f
    None -> 0.0
  }
}

pub fn opt_int_for_db(o: Option(Int)) -> Int {
  case o {
    Some(i) -> i
    None -> 0
  }
}

pub fn opt_string_from_db(s: String) -> Option(String) {
  case s {
    "" -> None
    _ -> Some(s)
  }
}
