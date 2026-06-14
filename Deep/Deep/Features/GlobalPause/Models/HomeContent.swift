import SwiftUI

/// What a piece of home content *is* — drives its small tag and glyph. Keeps the
/// home feed self-describing without reaching into the DeepSound domain.
enum ContentKind: Hashable {
  case session
  case meditation
  case soundscape
  case story

  var label: String {
    switch self {
    case .session:    return "Session"
    case .meditation: return "Meditation"
    case .soundscape: return "Soundscape"
    case .story:      return "Story"
    }
  }

  var glyph: String {
    switch self {
    case .session:    return "globe.asia.australia.fill"
    case .meditation: return "circle.hexagongrid.fill"
    case .soundscape: return "waveform"
    case .story:      return "moon.stars.fill"
    }
  }
}

/// Abstract gradient identities for home artwork, composed only from Deep theme
/// tokens. Local to the home so the feed stays independent of `ArtworkPalette`.
enum HomePalette: CaseIterable, Hashable {
  case dawn, tide, bloom, dusk, ember, mist

  var colors: [Color] {
    switch self {
    case .dawn:  return [.skyWash, .softLilac]
    case .tide:  return [.softLilac, .skyWash]
    case .bloom: return [.blushPowder, .softLilac]
    case .dusk:  return [.lavenderMist, .blushPowder]
    case .ember: return [.peachCloud, .blushPowder]
    case .mist:  return [.skyWash, .lavenderMist, .blushPowder]
    }
  }
}

/// A single piece of home content (a card or a row).
struct HomeItem: Identifiable, Hashable {
  let id = UUID()
  let title: String
  let author: String
  let minutes: Int
  let palette: HomePalette
  let kind: ContentKind

  var durationLabel: String { "\(minutes) min" }
}

/// A content category surfaced in the "Explore" section.
enum HomeCategory: String, CaseIterable, Identifiable {
  case meditation = "Meditation"
  case sleep = "Sleep"
  case breath = "Breath"
  case music = "Music"

  var id: String { rawValue }

  var systemImage: String {
    switch self {
    case .meditation: return "circle.hexagongrid.fill"
    case .sleep:      return "moon.stars.fill"
    case .breath:     return "wind"
    case .music:      return "music.note"
    }
  }

  var tint: Color {
    switch self {
    case .meditation: return .lavenderMist
    case .sleep:      return .skyWash
    case .breath:     return .peachCloud
    case .music:      return .blushPowder
    }
  }
}

/// The promotional banner near the top of the feed.
struct HomeBanner: Hashable {
  let title: String
  let message: String
  let systemImage: String
}

/// Static mock content for the Global Pause home. Replace with live data later.
enum HomeLibrary {
  static let banner = HomeBanner(
    title: "Pause with the world",
    message: "Join the next synchronized Global Pause — thousands breathing together.",
    systemImage: "globe.asia.australia.fill"
  )

  static let popular: [HomeItem] = [
    HomeItem(title: "One Quiet Minute", author: "Global Pause", minutes: 1, palette: .dawn, kind: .session),
    HomeItem(title: "Coming Home to Breath", author: "Lina Suwan", minutes: 12, palette: .dusk, kind: .meditation),
    HomeItem(title: "Tide & Stillness", author: "Deep", minutes: 30, palette: .tide, kind: .soundscape),
    HomeItem(title: "The Weight of the Day", author: "Akio Mori", minutes: 18, palette: .mist, kind: .story)
  ]

  static let todaysSessions: [HomeItem] = [
    HomeItem(title: "Morning Arrival", author: "Daily Pause", minutes: 6, palette: .ember, kind: .session),
    HomeItem(title: "Soften the Shoulders", author: "Prof. Mara Reix", minutes: 4, palette: .bloom, kind: .meditation),
    HomeItem(title: "Gratitude for Today", author: "Chiba Okere", minutes: 5, palette: .dawn, kind: .meditation),
    HomeItem(title: "Evening Wind-Down", author: "Deep", minutes: 20, palette: .dusk, kind: .soundscape)
  ]

  static let recommended: [HomeItem] = [
    HomeItem(title: "Daily Move", author: "A gentle reset · Focus", minutes: 6, palette: .ember, kind: .session),
    HomeItem(title: "Infinite Ambient", author: "Generative calm for deep rest", minutes: 45, palette: .tide, kind: .soundscape),
    HomeItem(title: "Present in the Body", author: "Prof. Mara Reix", minutes: 4, palette: .mist, kind: .meditation)
  ]
}

#if DEBUG
extension HomeItem {
  static let sample = HomeLibrary.popular[1]
}
#endif
