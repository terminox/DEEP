import Foundation

/// Saved sounds for previews and tests, drawn from the bundled `SoundLibrary`.
///
/// Deliberately spread across several collections: a playlist's whole point is
/// that consecutive sounds come from different places, and a fixture that took
/// them all from one album would hide every bug in that.
enum PlaylistFixtures {
  /// Every library track paired with the collection it came from — what a
  /// `MockPlaylistRemote` saves *from*.
  static let everyTrack: [SoundQueueEntry] = sources.flatMap { collection in
    collection.tracks.map { SoundQueueEntry(track: $0, collection: collection) }
  }

  /// A playlist with a few sounds saved, newest first.
  static let saved = Playlist(
    id: "playlist-1",
    name: "Playlist",
    isDefault: true,
    entries: picks.enumerated().map { offset, pick in
      PlaylistEntry(
        id: "item-\(offset)",
        track: pick.track,
        collection: pick.collection,
        // Saved a few minutes apart, most recent first.
        savedAt: Date(timeIntervalSinceNow: -Double(offset) * 900)
      )
    }
  )

  /// Nothing saved yet — the invitation state.
  static let empty = Playlist(
    id: "playlist-1",
    name: "Playlist",
    isDefault: true,
    entries: []
  )

  private static let sources: [SoundCollection] = [
    SoundLibrary.sleep[0],
    SoundLibrary.calm[0],
    SoundLibrary.morning[0],
    SoundLibrary.deepTeacher[0],
  ]

  /// One sound from each source collection, so the rows show four different
  /// artworks.
  private static let picks: [SoundQueueEntry] = sources.enumerated().compactMap { offset, collection in
    collection.tracks.indices.contains(offset)
      ? SoundQueueEntry(track: collection.tracks[offset], collection: collection)
      : collection.tracks.first.map { SoundQueueEntry(track: $0, collection: collection) }
  }
}
