import gleam/list
import gleam/string

pub fn pascal_to_snake(s: String) -> String {
  let cps = string.to_utf_codepoints(s)
  let out =
    list.index_fold(cps, [], fn(acc, cp, i) {
      let lower = ascii_lower_codepoint(cp)
      case i > 0 && is_upper_ascii(cp) {
        True -> list.append(acc, [underscore_cp(), lower])
        False -> list.append(acc, [lower])
      }
    })
  string.from_utf_codepoints(out)
}

fn underscore_cp() {
  let assert Ok(cp) = string.utf_codepoint(95)
  cp
}

fn is_upper_ascii(cp) -> Bool {
  let i = string.utf_codepoint_to_int(cp)
  i >= 65 && i <= 90
}

fn ascii_lower_codepoint(cp) {
  let i = string.utf_codepoint_to_int(cp)
  case i >= 65 && i <= 90 {
    True -> {
      let assert Ok(lower) = string.utf_codepoint(i + 32)
      lower
    }
    False -> cp
  }
}
