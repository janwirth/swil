//// Public API for `library_manager_advanced_db`.

import case_studies/library_manager_advanced_db/migration
import case_studies/library_manager_advanced_db/query
import case_studies/library_manager_advanced_schema as schema
import dsl/dsl
import sqlight

pub fn migrate(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  migration.migration(conn)
}

pub fn query_tracks_by_view_config(
  conn: sqlight.Connection,
  filter: schema.FilterExpressionScalar,
) -> Result(List(#(schema.TrackBucket, dsl.MagicFields)), sqlight.Error) {
  query.query_tracks_by_view_config(conn, filter)
}

pub fn last_100_edited_trackbucket(
  conn: sqlight.Connection,
) -> Result(List(#(schema.TrackBucket, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_trackbucket(conn)
}

pub fn last_100_edited_tag(
  conn: sqlight.Connection,
) -> Result(List(#(schema.Tag, dsl.MagicFields)), sqlight.Error) {
  query.last_100_edited_tag(conn)
}
