import SwiftUI

/// A single track inside a collection.
///
/// Deep Sound ships instrumental soundscapes for now, but `kind` leaves room
/// for spoken-word guided meditations later without reshaping the model.
struct SoundTrack: Identifiable, Hashable {
  enum Kind: Hashable {
    case instrumental
    case guided
  }

  let id = UUID()
  let title: String
  let duration: TimeInterval
  var kind: Kind = .instrumental
}

/// A collection of tracks — Deep Sound's equivalent of an album.
/// There is no surfaced creator; a collection stands on its own.
struct SoundCollection: Identifiable, Hashable {
  let id = UUID()
  let title: String
  /// Short descriptor shown under the title, e.g. "Ocean field recording".
  let subtitle: String
  /// Drives the generated gradient artwork (no bitmap assets yet).
  let palette: ArtworkPalette
  let tracks: [SoundTrack]

  var trackCount: Int { tracks.count }
  var totalDuration: TimeInterval { tracks.reduce(0) { $0 + $1.duration } }
}

/// A browse-by-intention category tile.
struct SoundIntention: Identifiable, Hashable {
  let id = UUID()
  let title: String
  let palette: ArtworkPalette
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
