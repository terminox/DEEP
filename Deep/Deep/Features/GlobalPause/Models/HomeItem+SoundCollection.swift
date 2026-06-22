import Foundation

/// Bridges a Global Pause `HomeItem` into the DeepSound player's `SoundCollection`
/// so tapping a home card can drive the shared mini-player + Now Playing.
///
/// This is the **only** place Global Pause couples to `ArtworkPalette`; the rest of
/// the feed stays on its own `HomePalette` so the two homes remain independent.
extension HomeItem {
  /// A single-track collection the player can start. `minutes` becomes the track
  /// duration; `author` becomes the collection subtitle.
  var asSoundCollection: SoundCollection {
    SoundCollection(
      title: title,
      subtitle: author,
      palette: artworkPalette,
      imageURL: imageURL,
      tracks: [
        SoundTrack(
          title: title,
          duration: TimeInterval(minutes * 60),
          kind: (kind == .meditation || kind == .story) ? .guided : .instrumental
        )
      ]
    )
  }

  /// Maps the home gradient identity to its DeepSound twin. The pairs share
  /// identical colour stops, so the artwork reads the same on both sides.
  private var artworkPalette: ArtworkPalette {
    switch palette {
    case .dawn:  return .tide
    case .tide:  return .mist
    case .bloom: return .bloom
    case .dusk:  return .dusk
    case .ember: return .ember
    case .mist:  return .aurora
    }
  }
}
