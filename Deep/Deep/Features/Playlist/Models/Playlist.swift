import Foundation

/// One sound a listener saved, together with the collection it came from — the
/// artwork and the origin name a row needs without a second fetch.
///
/// `Codable` so `PlaylistStore` can hold its last snapshot on disk; an offline
/// cold launch then opens on the saved sounds rather than an empty state.
struct PlaylistEntry: Identifiable, Hashable, Codable {
  /// The playlist item's id, not the track's — the same sound saved in two
  /// playlists is two entries.
  let id: String
  let track: SoundTrack
  /// Where the sound came from. Arrives without its own tracks: a row needs
  /// the artwork and the name, nothing more.
  let collection: SoundCollection
  let savedAt: Date

  /// How this entry enters the player's queue.
  var queueEntry: SoundQueueEntry {
    SoundQueueEntry(track: track, collection: collection)
  }
}

/// A listener's own list of sounds. One per person today, but everything here
/// and on the wire is a *list* of playlists, so a second one is an addition
/// rather than a reshape.
struct Playlist: Identifiable, Hashable, Codable {
  let id: String
  let name: String
  /// The list created automatically for every listener — "the user's Playlist"
  /// while there is only one.
  let isDefault: Bool
  /// Most recently saved first.
  var entries: [PlaylistEntry]

  var trackCount: Int { entries.count }
  var totalDuration: TimeInterval { entries.reduce(0) { $0 + $1.track.duration } }
}
