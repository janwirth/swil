import gleam/string

/// Generator-time panic `as` message for `apply_one_*_column_fix` when no rule matches.
pub fn no_column_fix_message(module_tag: String) -> String {
  string.append(module_tag, ": no column fix applies")
}

/// Generator-time panic `as` message when column reconcile exceeds the iteration cap.
pub fn column_reconcile_no_convergence_message(module_tag: String) -> String {
  string.append(module_tag, ": column reconcile did not converge")
}
