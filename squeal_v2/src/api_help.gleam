import gleam/option.{type Option, None, Some}
import gleam/time/timestamp

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
