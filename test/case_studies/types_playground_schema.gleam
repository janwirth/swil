import gleam/time/timestamp.{type Timestamp}
import gleam/option
pub type MyTrack {
    MyTrack(
        added_to_playlist_at: option.Option(Timestamp),
        name: option.Option(String),
        identities: MyTrackIdentities,
    )
}

pub type MyTrackIdentities {
    ByName(name: String)
}