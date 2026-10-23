import SwiftUI

/// A single track inside a collection.
///
/// `kind` distinguishes instrumental soundscapes from spoken-word guided
/// meditations. `audioURL` is the streaming source (served by the backend);
/// `isPremium` marks the track as DEEP Premium, and `isLocked` is the server's
/// own verdict for the listener who asked (see `PremiumGate`). Ids are
/// server-assigned strings (a stable default is generated for fixtures/bridges).
struct SoundTrack: Identifiable, Hashable, Codable {
  enum Kind: Hashable, Codable {
    case instrumental
    case guided
  }

  let id: String
  let title: String
  let duration: TimeInterval
  var kind: Kind = .instrumental
  /// Streaming audio source. `nil` for fixture/preview content (no real audio).
  var audioURL: URL? = nil
  var isPremium: Bool = false
  /// Whether the server withheld this track from the listener who fetched it.
  /// `nil` when the answer never came — an older server, or content cached
  /// before the field existed — and `PremiumGate` falls back to the client rule.
  /// Optional on purpose: the synthesized decoder reads optionals with
  /// `decodeIfPresent`, so playlists cached without it still decode.
  var isLocked: Bool? = nil

  init(
    id: String = UUID().uuidString,
    title: String,
    duration: TimeInterval,
    kind: Kind = .instrumental,
    audioURL: URL? = nil,
    isPremium: Bool = false,
    isLocked: Bool? = nil
  ) {
    self.id = id
    self.title = title
    self.duration = duration
    self.kind = kind
    self.audioURL = audioURL
    self.isPremium = isPremium
    self.isLocked = isLocked
  }
}

/// A track together with the collection it came from.
///
/// A collection plays as a run of entries that all share one collection; a
/// playlist's entries each carry their own, so artwork and the origin line
/// follow the track rather than the queue it happens to be sitting in.
struct SoundQueueEntry: Hashable {
  let track: SoundTrack
  /// Where the track came from — its artwork and its name. Carries no tracks
  /// of its own when it arrives with a playlist.
  let collection: SoundCollection
}

/// A collection of tracks — DEEP Sound's equivalent of an album.
/// There is no surfaced creator; a collection stands on its own.
struct SoundCollection: Identifiable, Hashable, Codable {
  let id: String
  let title: String
  /// Short descriptor shown under the title, e.g. "Ocean field recording".
  let subtitle: String
  /// Tints the artwork and seeds the gradient fallback while the photo loads.
  let palette: ArtworkPalette
  /// Photograph shown beneath the palette wash. `nil` keeps the pure gradient.
  let imageURL: URL?
  /// Owning category id (from the backend). Empty for bridged/fixture content.
  var categoryId: String = ""
  var isPremium: Bool = false
  /// The server's verdict for the listener who fetched it; `nil` when it never
  /// said. Optional for the same cache-compatibility reason as the track's.
  var isLocked: Bool? = nil
  let tracks: [SoundTrack]

  init(
    id: String = UUID().uuidString,
    title: String,
    subtitle: String,
    palette: ArtworkPalette,
    imageURL: URL?,
    categoryId: String = "",
    isPremium: Bool = false,
    isLocked: Bool? = nil,
    tracks: [SoundTrack]
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.palette = palette
    self.imageURL = imageURL
    self.categoryId = categoryId
    self.isPremium = isPremium
    self.isLocked = isLocked
    self.tracks = tracks
  }

  var trackCount: Int { tracks.count }
  var totalDuration: TimeInterval { tracks.reduce(0) { $0 + $1.duration } }
}

extension TimeInterval {
  /// Clock string like "4:05" used by track rows and the scrubber.
  var clockString: String {
    let total = Int(rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  /// Human duration like "32 min" for collection metadata.
  var minutesString: String {
    let minutes = max(1, Int((self / 60).rounded()))
    return "\(minutes) min"
  }
}
