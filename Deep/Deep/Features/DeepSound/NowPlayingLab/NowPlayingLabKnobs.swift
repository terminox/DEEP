#if DEBUG
import Foundation
import DialKit

/// THROWAWAY. Everything the full-screen player prototype can be tuned by.
///
/// Four layouts that put the track artwork (almost) full screen, plus the
/// current player as the baseline, switchable live on the simulator. Answers
/// one question: "what should a near-full-screen-artwork player look like?"
struct NowPlayingLabKnobs: Codable, Equatable {
  /// Always a live catalog id (DialKit's `.select` falls back to the initial
  /// value when the current one isn't among the options).
  var variant = NowPlayingLabCatalog.defaultID

  /// `playing` keeps the loaded collection's photo; any other id swaps in a
  /// fixture photo so each layout can be judged on light and dark artwork.
  var artwork = NowPlayingLabArtwork.playing.rawValue

  /// 0...1 strength of the plum scrims that seat text over a photograph.
  var scrim = 0.8
  /// Inset card only: the pale margin left around the artwork card.
  var cardInset = 12.0
  /// A2 only: peak radius of the progressive blur under the controls.
  var blurRadius = 24.0
  /// Slow drift on the artwork while playing; freezes (and dims) on pause.
  var breathes = true

  static let controls: [DialControl<NowPlayingLabKnobs>] = [
    // First and ungrouped: the control touched every few seconds.
    .select(
      "variant",
      keyPath: \.variant,
      label: "Variant",
      options: NowPlayingLabCatalog.all.map { DialOption($0.id, label: $0.label) }
    ),
    .select(
      "artwork",
      keyPath: \.artwork,
      label: "Artwork",
      options: NowPlayingLabArtwork.allCases.map { DialOption($0.rawValue, label: $0.label) }
    ),
    .group("look", label: "Look", collapsed: false, children: [
      .slider("scrim", keyPath: \.scrim, label: "Scrim", range: 0.0...1.0, step: 0.05),
      .slider("cardInset", keyPath: \.cardInset, label: "Card inset", range: 0.0...32.0, step: 2.0, unit: "pt"),
      .slider("blurRadius", keyPath: \.blurRadius, label: "A2 blur", range: 0.0...60.0, step: 2.0, unit: "pt"),
      .toggle("breathes", keyPath: \.breathes, label: "Breathing art")
    ])
  ]
}

/// THROWAWAY. Fixture photos to judge a layout against, from the brightest
/// sky to the darkest night. Requested at 1400px — the 600px fixtures go soft
/// when stretched across a whole screen.
enum NowPlayingLabArtwork: String, CaseIterable {
  case playing
  case mountain
  case mist
  case fields
  case forest
  case ocean
  case aurora
  case stars

  var label: String {
    switch self {
    case .playing: "Playing (real)"
    case .mountain: "Mountain · pale"
    case .mist: "Morning mist · pale"
    case .fields: "Golden fields · warm"
    case .forest: "Still forest · dark"
    case .ocean: "Ocean · mid"
    case .aurora: "Aurora · dark"
    case .stars: "Stars · night"
    }
  }

  var url: URL? {
    let photo: String? = switch self {
    case .playing: nil
    case .mountain: "photo-1469474968028-56623f02e42e"
    case .mist: "photo-1470071459604-3b5ec3a7fe05"
    case .fields: "photo-1472214103451-9374bd1c798e"
    case .forest: "photo-1441974231531-c6227db76b6e"
    case .ocean: "photo-1505144808419-1957a94ca61e"
    case .aurora: "photo-1483347756197-71ef80e95f73"
    case .stars: "photo-1462331940025-496dfbfc7564"
    }
    return photo.flatMap { URL(string: "https://images.unsplash.com/\($0)?w=1400&q=80") }
  }

  /// The collection's own photo, upsized when it is an Unsplash fixture.
  static func upsized(_ url: URL?) -> URL? {
    guard let url, url.host()?.contains("unsplash") == true else { return url }
    return URL(string: url.absoluteString.replacingOccurrences(of: "w=600", with: "w=1400"))
  }
}
#endif
