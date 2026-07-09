import Foundation

/// Sample content for the UI. No networking, no audio — just enough shape to
/// make the home, detail, and player screens feel alive. Collections are
/// grouped into the five home-screen categories.
enum SoundLibrary {
  /// "Calm" — settled skies and still places.
  static let calm: [SoundCollection] = [
    SoundCollection(
      title: "Northern Calm",
      subtitle: "Wide skies, settled breath",
      palette: .aurora,
      imageURL: URL(string: "https://images.unsplash.com/photo-1483347756197-71ef80e95f73?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Aurora Drift", duration: 9 * 60 + 16),
        SoundTrack(title: "Polar Stillness", duration: 7 * 60 + 48),
        SoundTrack(title: "Open Sky", duration: 6 * 60 + 30),
        SoundTrack(title: "Far Horizon", duration: 8 * 60 + 2)
      ]
    ),
    SoundCollection(
      title: "Petal Fall",
      subtitle: "Gentle bloom for an open heart",
      palette: .bloom,
      imageURL: URL(string: "https://images.unsplash.com/photo-1457089328109-e5d9bd499191?w=600&q=80"),
      tracks: [
        SoundTrack(title: "First Blossom", duration: 5 * 60 + 50),
        SoundTrack(title: "Soft Unfolding", duration: 7 * 60 + 14),
        SoundTrack(title: "Drifting Petals", duration: 6 * 60 + 22),
        SoundTrack(title: "Resting Garden", duration: 9 * 60 + 40)
      ]
    ),
    SoundCollection(
      title: "Still Forest",
      subtitle: "Green quiet between the trees",
      palette: .mist,
      imageURL: URL(string: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Under the Canopy", duration: 7 * 60 + 26),
        SoundTrack(title: "Moss and Shade", duration: 6 * 60 + 54),
        SoundTrack(title: "Leaf Light", duration: 8 * 60 + 12)
      ]
    ),
    SoundCollection(
      title: "Mountain Air",
      subtitle: "Thin, clear, and endlessly calm",
      palette: .aurora,
      imageURL: URL(string: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600&q=80"),
      tracks: [
        SoundTrack(title: "High Meadow", duration: 6 * 60 + 8),
        SoundTrack(title: "Ridge Line", duration: 7 * 60 + 34),
        SoundTrack(title: "Snowmelt", duration: 5 * 60 + 46),
        SoundTrack(title: "Summit Stillness", duration: 8 * 60 + 50)
      ]
    )
  ]

  /// "Morning" — a soft return to the day.
  static let morning: [SoundCollection] = [
    SoundCollection(
      title: "Morning Mist",
      subtitle: "A soft return to the day",
      palette: .mist,
      imageURL: URL(string: "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=600&q=80"),
      tracks: [
        SoundTrack(title: "First Light", duration: 5 * 60 + 12),
        SoundTrack(title: "Dew", duration: 6 * 60 + 58),
        SoundTrack(title: "Slow Waking", duration: 8 * 60 + 24)
      ]
    ),
    SoundCollection(
      title: "First Sun",
      subtitle: "Warmth arriving over the hills",
      palette: .dawn,
      imageURL: URL(string: "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Horizon Glow", duration: 6 * 60 + 18),
        SoundTrack(title: "Waking Fields", duration: 7 * 60 + 42),
        SoundTrack(title: "Gold Through Mist", duration: 5 * 60 + 36)
      ]
    ),
    SoundCollection(
      title: "Golden Fields",
      subtitle: "Slow light across open land",
      palette: .ember,
      imageURL: URL(string: "https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Harvest Hush", duration: 7 * 60 + 8),
        SoundTrack(title: "Wind in the Wheat", duration: 6 * 60 + 46),
        SoundTrack(title: "Late Morning", duration: 8 * 60 + 20),
        SoundTrack(title: "Open Path", duration: 5 * 60 + 58)
      ]
    ),
    SoundCollection(
      title: "Sea at Dawn",
      subtitle: "The coast before anyone wakes",
      palette: .dawn,
      imageURL: URL(string: "https://images.unsplash.com/photo-1475924156734-496f6cac6ec1?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Pale Tide", duration: 6 * 60 + 32),
        SoundTrack(title: "Early Gulls", duration: 5 * 60 + 44),
        SoundTrack(title: "Salt and Light", duration: 7 * 60 + 56)
      ]
    )
  ]

  /// "Sleep" — slow tides and low light for deep rest.
  static let sleep: [SoundCollection] = [
    SoundCollection(
      title: "Ocean Depths",
      subtitle: "Slow tides for deep rest",
      palette: .tide,
      imageURL: URL(string: "https://images.unsplash.com/photo-1505144808419-1957a94ca61e?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Drifting Tide", duration: 6 * 60 + 12),
        SoundTrack(title: "Beneath the Surface", duration: 8 * 60 + 40),
        SoundTrack(title: "Moonlit Current", duration: 5 * 60 + 28),
        SoundTrack(title: "Still Water", duration: 9 * 60 + 4)
      ]
    ),
    SoundCollection(
      title: "Evening Light",
      subtitle: "Wind down as the day softens",
      palette: .dusk,
      imageURL: URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Last Warmth", duration: 7 * 60 + 2),
        SoundTrack(title: "Fading Gold", duration: 6 * 60 + 36),
        SoundTrack(title: "Quiet Sky", duration: 8 * 60 + 18)
      ]
    ),
    SoundCollection(
      title: "Hearthglow",
      subtitle: "Warm tones to feel held",
      palette: .ember,
      imageURL: URL(string: "https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Low Embers", duration: 8 * 60 + 6),
        SoundTrack(title: "Candle Hour", duration: 6 * 60 + 44),
        SoundTrack(title: "Held Warmth", duration: 7 * 60 + 30)
      ]
    ),
    SoundCollection(
      title: "Starfall",
      subtitle: "Night skies to drift beneath",
      palette: .tide,
      imageURL: URL(string: "https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Falling Slow", duration: 8 * 60 + 34),
        SoundTrack(title: "Midnight Meadow", duration: 7 * 60 + 12),
        SoundTrack(title: "Deep Dark", duration: 9 * 60 + 48),
        SoundTrack(title: "Before Dreams", duration: 6 * 60 + 26)
      ]
    )
  ]

  /// "Deep Teacher" — a steady voice to practice alongside.
  static let deepTeacher: [SoundCollection] = [
    SoundCollection(
      title: "Roots of Attention",
      subtitle: "A teacher's voice to steady you",
      palette: .aurora,
      imageURL: URL(string: "https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Arriving", duration: 5 * 60 + 20),
        SoundTrack(title: "Softening the Shoulders", duration: 6 * 60 + 48),
        SoundTrack(title: "Naming the Breath", duration: 7 * 60 + 16),
        SoundTrack(title: "Staying a While", duration: 8 * 60 + 4)
      ]
    ),
    SoundCollection(
      title: "Letting Go",
      subtitle: "Guided release at day's end",
      palette: .dusk,
      imageURL: URL(string: "https://images.unsplash.com/photo-1476673160081-cf065607f449?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Setting Down the Day", duration: 6 * 60 + 30),
        SoundTrack(title: "Unclenching", duration: 5 * 60 + 52),
        SoundTrack(title: "The Long Exhale", duration: 7 * 60 + 38)
      ]
    ),
    SoundCollection(
      title: "Body & Breath",
      subtitle: "A gentle scan from crown to toes",
      palette: .mist,
      imageURL: URL(string: "https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Crown and Brow", duration: 6 * 60 + 14),
        SoundTrack(title: "Heart Space", duration: 7 * 60 + 26),
        SoundTrack(title: "Grounding the Feet", duration: 5 * 60 + 40)
      ]
    ),
    SoundCollection(
      title: "Evening Reflection",
      subtitle: "Quiet questions before sleep",
      palette: .tide,
      imageURL: URL(string: "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600&q=80"),
      tracks: [
        SoundTrack(title: "What Softened Today", duration: 6 * 60 + 2),
        SoundTrack(title: "Gratitude Hour", duration: 7 * 60 + 44),
        SoundTrack(title: "Closing the Day", duration: 8 * 60 + 28)
      ]
    )
  ]

  /// "Deep Kids" — small, kind soundscapes for little listeners.
  static let deepKids: [SoundCollection] = [
    SoundCollection(
      title: "Sleepy Stars",
      subtitle: "A twinkling lullaby sky",
      palette: .tide,
      imageURL: URL(string: "https://images.unsplash.com/photo-1462331940025-496dfbfc7564?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Counting Starlight", duration: 4 * 60 + 36),
        SoundTrack(title: "The Moon's Blanket", duration: 5 * 60 + 22),
        SoundTrack(title: "Goodnight Sky", duration: 6 * 60 + 10)
      ]
    ),
    SoundCollection(
      title: "Little Shore",
      subtitle: "Tiny waves for tiny toes",
      palette: .dawn,
      imageURL: URL(string: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&q=80"),
      tracks: [
        SoundTrack(title: "The Smallest Wave", duration: 5 * 60 + 8),
        SoundTrack(title: "Seashell Whispers", duration: 4 * 60 + 54),
        SoundTrack(title: "Sandcastle Dreams", duration: 6 * 60 + 32)
      ]
    ),
    SoundCollection(
      title: "Flower Friends",
      subtitle: "A garden of gentle hellos",
      palette: .bloom,
      imageURL: URL(string: "https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Buttercup Waves Hello", duration: 4 * 60 + 42),
        SoundTrack(title: "The Bumblebee Parade", duration: 5 * 60 + 16),
        SoundTrack(title: "Petal Naps", duration: 6 * 60 + 4)
      ]
    ),
    SoundCollection(
      title: "Big Blue Wave",
      subtitle: "Ride the friendly ocean home",
      palette: .tide,
      imageURL: URL(string: "https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Splash and Glide", duration: 5 * 60 + 30),
        SoundTrack(title: "The Whale's Hum", duration: 6 * 60 + 46),
        SoundTrack(title: "Drifting to Shore", duration: 4 * 60 + 58)
      ]
    )
  ]
}
