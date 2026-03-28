import case_studies/library_manager_advanced_db/row
import case_studies/library_manager_advanced_schema
import dsl/dsl
import gleam/dynamic/decode
import gleam/list
import gleam/string
import sqlight

const last_100_tab_sql = "select \"label\", \"order\", \"view_config\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tab\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

const last_100_trackbucket_sql = "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

const last_100_tag_sql = "select \"label\", \"emoji\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"tag\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

const last_100_importedtrack_sql = "select \"title\", \"artist\", \"file_path\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"importedtrack\" where \"deleted_at\" is null order by \"updated_at\" desc limit 100;"

/// List up to 100 recently edited tab rows.
pub fn last_100_edited_tab(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_advanced_schema.Tab, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    last_100_tab_sql,
    on: conn,
    with: [],
    expecting: row.tab_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited trackbucket rows.
pub fn last_100_edited_trackbucket(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_advanced_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    last_100_trackbucket_sql,
    on: conn,
    with: [],
    expecting: row.trackbucket_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited tag rows.
pub fn last_100_edited_tag(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_advanced_schema.Tag, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    last_100_tag_sql,
    on: conn,
    with: [],
    expecting: row.tag_with_magic_row_decoder(),
  )
}

/// List up to 100 recently edited importedtrack rows.
pub fn last_100_edited_importedtrack(
  conn: sqlight.Connection,
) -> Result(
  List(#(library_manager_advanced_schema.ImportedTrack, dsl.MagicFields)),
  sqlight.Error,
) {
  sqlight.query(
    last_100_importedtrack_sql,
    on: conn,
    with: [],
    expecting: row.importedtrack_with_magic_row_decoder(),
  )
}

fn tag_filter_to_sql(
  filter: library_manager_advanced_schema.FilterExpressionScalar,
  root_alias: String,
) -> #(String, List(sqlight.Value)) {
  case filter {
    dsl.And(exprs) -> {
      let parts = list.map(exprs, fn(e) { tag_filter_to_sql(e, root_alias) })
      let sqls = list.map(parts, fn(p) { p.0 })
      let binds = list.flat_map(parts, fn(p) { p.1 })
      #(string.join(sqls, " and "), binds)
    }
    dsl.Or(exprs) -> {
      let parts = list.map(exprs, fn(e) { tag_filter_to_sql(e, root_alias) })
      let sqls = list.map(parts, fn(p) { p.0 })
      let binds = list.flat_map(parts, fn(p) { p.1 })
      #("(" <> string.join(sqls, " or ") <> ")", binds)
    }
    dsl.Not(expr) -> {
      let #(inner_sql, binds) = tag_filter_to_sql(expr, root_alias)
      #("not (" <> inner_sql <> ")", binds)
    }
    dsl.Predicate(leaf) -> tag_predicate_to_sql(leaf, root_alias)
  }
}

fn tag_predicate_to_sql(
  leaf: library_manager_advanced_schema.TagExpressionScalar,
  root_alias: String,
) -> #(String, List(sqlight.Value)) {
  case leaf {
    library_manager_advanced_schema.Has(tag_id: tag_id) -> #(
      "exists (select 1 from \"trackbucket_tag\" as rel join \"tag\" as t on t.\"id\" = rel.\"tag_id\" and t.\"deleted_at\" is null where rel.\"trackbucket_id\" = "
        <> root_alias
        <> ".\"id\" and t.\"id\" = ?"
        <> ")",
      [sqlight.int(tag_id)],
    )
    library_manager_advanced_schema.IsAtLeast(tag_id: tag_id, value: value) -> #(
      "exists (select 1 from \"trackbucket_tag\" as rel join \"tag\" as t on t.\"id\" = rel.\"tag_id\" and t.\"deleted_at\" is null where rel.\"trackbucket_id\" = "
        <> root_alias
        <> ".\"id\" and t.\"id\" = ? and rel.\"value\" >= ?"
        <> ")",
      [sqlight.int(tag_id), sqlight.int(value)],
    )
    library_manager_advanced_schema.IsAtMost(tag_id: tag_id, value: value) -> #(
      "exists (select 1 from \"trackbucket_tag\" as rel join \"tag\" as t on t.\"id\" = rel.\"tag_id\" and t.\"deleted_at\" is null where rel.\"trackbucket_id\" = "
        <> root_alias
        <> ".\"id\" and t.\"id\" = ? and rel.\"value\" <= ?"
        <> ")",
      [sqlight.int(tag_id), sqlight.int(value)],
    )
    library_manager_advanced_schema.IsEqualTo(tag_id: tag_id, value: value) -> #(
      "exists (select 1 from \"trackbucket_tag\" as rel join \"tag\" as t on t.\"id\" = rel.\"tag_id\" and t.\"deleted_at\" is null where rel.\"trackbucket_id\" = "
        <> root_alias
        <> ".\"id\" and t.\"id\" = ? and rel.\"value\" = ?"
        <> ")",
      [sqlight.int(tag_id), sqlight.int(value)],
    )
  }
}

fn query_tracks_by_view_config_sql_with(
  filter: library_manager_advanced_schema.FilterExpressionScalar,
) -> #(String, List(sqlight.Value)) {
  let #(filter_sql, binds) = tag_filter_to_sql(filter, "tb")
  #(
    "select \"title\", \"artist\", \"id\", \"created_at\", \"updated_at\", \"deleted_at\" from \"trackbucket\" as tb where tb.\"deleted_at\" is null and "
      <> filter_sql
      <> " order by tb.\"updated_at\" desc",
    binds,
  )
}

pub fn query_tracks_by_view_config(
  conn: sqlight.Connection,
  filter: library_manager_advanced_schema.FilterExpressionScalar,
) -> Result(
  List(#(library_manager_advanced_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  let #(sql, binds) = query_tracks_by_view_config_sql_with(filter)
  sqlight.query(
    sql,
    on: conn,
    with: binds,
    expecting: row.trackbucket_with_magic_row_decoder(),
  )
}

pub fn filter_expression_decoder() -> decode.Decoder(
  library_manager_advanced_schema.FilterExpressionScalar,
) {
  bool_filter_decoder(tag_expression_decoder())
}

fn bool_filter_decoder(
  leaf_dec: decode.Decoder(a),
) -> decode.Decoder(dsl.BooleanFilter(a)) {
  decode.recursive(fn() { bool_filter_decoder_inner(leaf_dec) })
}

fn bool_filter_decoder_inner(
  leaf_dec: decode.Decoder(a),
) -> decode.Decoder(dsl.BooleanFilter(a)) {
  use tag <- decode.field("tag", decode.string)
  case tag {
    "And" -> {
      use exprs <- decode.field(
        "exprs",
        decode.list(bool_filter_decoder(leaf_dec)),
      )
      decode.success(dsl.And(exprs))
    }
    "Or" -> {
      use exprs <- decode.field(
        "exprs",
        decode.list(bool_filter_decoder(leaf_dec)),
      )
      decode.success(dsl.Or(exprs))
    }
    "Not" -> {
      use expr <- decode.field("expr", bool_filter_decoder(leaf_dec))
      decode.success(dsl.Not(expr))
    }
    "Predicate" -> {
      use item <- decode.field("item", leaf_dec)
      decode.success(dsl.Predicate(item))
    }
    _ -> decode.failure(dsl.And([]), "unknown BooleanFilter tag: " <> tag)
  }
}

pub fn tag_expression_decoder() -> decode.Decoder(
  library_manager_advanced_schema.TagExpressionScalar,
) {
  use tag <- decode.field("tag", decode.string)
  case tag {
    "Has" -> {
      use tag_id <- decode.field("tag_id", decode.int)
      decode.success(library_manager_advanced_schema.Has(tag_id: tag_id))
    }
    "IsAtLeast" -> {
      use tag_id <- decode.field("tag_id", decode.int)
      use value <- decode.field("value", decode.int)
      decode.success(library_manager_advanced_schema.IsAtLeast(
        tag_id: tag_id,
        value: value,
      ))
    }
    "IsAtMost" -> {
      use tag_id <- decode.field("tag_id", decode.int)
      use value <- decode.field("value", decode.int)
      decode.success(library_manager_advanced_schema.IsAtMost(
        tag_id: tag_id,
        value: value,
      ))
    }
    "IsEqualTo" -> {
      use tag_id <- decode.field("tag_id", decode.int)
      use value <- decode.field("value", decode.int)
      decode.success(library_manager_advanced_schema.IsEqualTo(
        tag_id: tag_id,
        value: value,
      ))
    }
    _ ->
      decode.failure(
        library_manager_advanced_schema.Has(tag_id: 0),
        "unknown TagExpressionScalar tag: " <> tag,
      )
  }
}
