import SwiftUI

/// A single track inside a collection.
///
/// `kind` distinguishes instrumental soundscapes from spoken-word guided
/// meditations. `audioURL` is the streaming source (served by the backend);
/// `isPremium` gates the track behind a subscription. Ids are server-assigned
/// strings (a stable default is generated for fixtures/bridges).
struct SoundTrack: Identifiable, Hashable {
  enum Kind: Hashable {
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

  init(
    id: String = UUID().uuidString,
    title: String,
    duration: TimeInterval,
    kind: Kind = .instrumental,
    audioURL: URL? = nil,
    isPremium: Bool = false
  ) {
    self.id = id
    self.title = title
    self.duration = duration
    self.kind = kind
    self.audioURL = audioURL
    self.isPremium = isPremium
  }
}

/// A collection of tracks — Deep Sound's equivalent of an album.
/// There is no surfaced creator; a collection stands on its own.
struct SoundCollection: Identifiable, Hashable {
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
  let tracks: [SoundTrack]

  init(
    id: String = UUID().uuidString,
    title: String,
    subtitle: String,
    palette: ArtworkPalette,
    imageURL: URL?,
    categoryId: String = "",
    isPremium: Bool = false,
    tracks: [SoundTrack]
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.palette = palette
    self.imageURL = imageURL
    self.categoryId = categoryId
    self.isPremium = isPremium
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
