import case_studies/library_manager_advanced_db/row
import case_studies/library_manager_advanced_schema
import dsl/dsl
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

// STUB — will be overwritten by generator
import gleam/dynamic/decode

pub fn query_tracks_by_view_config(
  _conn: sqlight.Connection,
  _filter: dsl.BooleanFilter(library_manager_advanced_schema.TagExpressionScalar),
) -> Result(
  List(#(library_manager_advanced_schema.TrackBucket, dsl.MagicFields)),
  sqlight.Error,
) {
  todo
}

pub fn filter_expression_decoder() -> decode.Decoder(
  dsl.BooleanFilter(library_manager_advanced_schema.TagExpressionScalar),
) {
  todo
}
