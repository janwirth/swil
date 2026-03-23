import gleam/option
import gleam/time/timestamp

// id
// created ad
// updated at
// - there atuomatically
pub type ImportedTrack {
  ImportedTrack(
    id: Int,
    // magic fields
    created_at: timestamp.Timestamp,
    // magic fields
    updated_at: timestamp.Timestamp,
    // magic fields
    title: option.Option(String),
    artist: option.Option(String),
    file_path: option.Option(String),
    tags: List(Tag),
  )
}

pub type Tag {
  Tag(
    id: Int,
    created_at: timestamp.Timestamp,
    updated_at: timestamp.Timestamp,
    label: String,
    emoji: option.Option(String),
  )
}

// should I think about types for this?
// without path nor XYZ is invalid?
// let's stay with this and validate later?

pub type ResolvedIdentity {
  ResolvedIdentity(
    id: Int,
    created_at: timestamp.Timestamp,
    updated_at: timestamp.Timestamp,
    title: option.Option(String),
    artist: option.Option(String),
    matched_tracks: List(ImportedTrack),
    // tag with a numeric param
    tags: List(#(Tag, Int)),
    // implies join table
  )
}

pub type Exclusive(a) {
  Exclusive(a)
}

pub type Scalar(a) {
  Scalar(a)
}

// persisted in db
pub type Tab {
  FilterTab(
    label: Exclusive(String),
    order: Float,
    filter_config: Scalar(FilterConfig),
  )
  SourceTab(label: Exclusive(String), order: Float, source_selector: String)
  // = flat data
}

// scalar is a single value, like a string, a number, a boolean, etc, not another object type in the db
// custom scalars could also be vectors
// scalars have their own implementaiton - to / from sql I guess

pub type FilterConfig

// todo: boolean filter structure
// list of sources
// all tracks
// list of tags (sidebar filter config - a la notion?)
// should tags even go into sidebar or should they be above?
// Let's keep this powerful

// parsed from URL or held in state, not persisted in db
type Route {
  Route(tab: Tab, mode: RouteModal)
}

type RouteModal {
  None
  Spotlight(query: String)
  // spotlight can
  // CRUD tabs
  // find individual tracks
}

// tags grouping is done by UI code

// let's think UI
// first think I see is
pub fn all_tabs() -> List(Tab) {
  // select * from tabs
  // 

  // this comes from DB and is reactive
  // how do I describe it?
  // execute sqlite query
  todo
}

pub fn all_tabs_for_header() -> List(Tab) {
  // select {label, order} from tabs
  // order by order
  todo
}

pub fn select(a, b) -> b {
  b
}

// pub type Field {
//     Field
// }
// pub type TabGenerated {
//     TabGenerated(
//         label: Field,
//         order: Field,
//         filter_config: Field,
//         source_selector: Field,
//     )
// }
// // placeholder
// type Infer {
//     Infer(Never)
// }

pub type Never {
  JustOneMore(Never)
}

// pub fn never_example() -> Never {   
//    JustOneMore(JustOneMore(JustOneMore(...))) // doesn't compile
// }

pub type Direction {
  Asc
  Desc
}

pub type OrderBy(field) {
  OrderBy(field: field, direction: Direction)
  NoOrderBy
}

pub fn order_by(field, direction) -> OrderBy(field) {
  todo
}

pub fn select_tabs_for_header(tab: Tab) -> OrderBy(c) {
  order_by(tab.order, Asc)
}

// query spec - also never executed
pub fn select_active_tab(tab: Tab) -> OrderBy(c) {
  NoOrderBy
  |> filter_single(fn(tab: Tab) -> Bool { tab.label == Exclusive("Active") })
}

// INTERNALS
// code-generation helpers - never executed
// query builder
pub fn filter_single(
  ord: OrderBy(field),
  predicate: fn(object_type) -> Bool,
) -> OrderBy(field) {
  todo
}

pub fn query(select: fn(object_type) -> OrderBy(field)) -> List(object_type) {
  // this is query implementation - fetching the 
  // generated per chema
  todo
}

pub fn query_single(
  select: fn(object_type) -> OrderBy(field),
) -> option.Option(object_type) {
  // this is query implementation - fetching the 
  // actual usage -> generated per schema
  todo
}

// EXAMPLE
pub fn in_render_example() -> List(Tab) {
  // can I sync exec this?
  // yes against sqlite inmem
  // sync exec this in runtime
  let tabs = query(select_tabs_for_header)
  let active_tab = query_single(select_active_tab)
  // final parsed results
  todo
}
// server components
// sync query against db connection
// why? distirbution easier
// let's kill this, work with just a desktop app.
// this saves a lot of trouble
// destkop app with embedded sqlite and lustre server components
// mobile app can re-use some things

// APPLICATION

// pub fn active_tab_renderer(scroll_offset: Int, filter_config: FilterConfig) -> List(Element) {
//     // let filter_editor
//     todo
// }
