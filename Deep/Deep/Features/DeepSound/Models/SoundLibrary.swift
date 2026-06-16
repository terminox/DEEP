import Foundation

/// Sample content for the UI. No networking, no audio — just enough shape to
/// make the home, detail, and player screens feel alive.
enum SoundLibrary {
  static let collections: [SoundCollection] = [
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
    )
  ]

  /// The hero feature at the top of the home screen.
  static var featured: SoundCollection { collections[0] }

  /// "Continue your practice" — recently touched collections.
  static var recent: [SoundCollection] {
    Array(collections.dropFirst())
  }

  /// "Made for you" — a second curated row.
  static var madeForYou: [SoundCollection] {
    Array(collections.shuffled().prefix(4))
  }

  static let intentions: [SoundIntention] = [
    SoundIntention(title: "Sleep", palette: .tide, imageURL: URL(string: "https://images.unsplash.com/photo-1483729558449-99ef09a8c325?w=600&q=80")),
    SoundIntention(title: "Calm", palette: .mist, imageURL: URL(string: "https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=600&q=80")),
    SoundIntention(title: "Focus", palette: .aurora, imageURL: URL(string: "https://images.unsplash.com/photo-1414609245224-afa02bfb3fda?w=600&q=80")),
    SoundIntention(title: "Unwind", palette: .dusk, imageURL: URL(string: "https://images.unsplash.com/photo-1490604001847-b712b0c2f967?w=600&q=80")),
    SoundIntention(title: "Breathe", palette: .bloom, imageURL: URL(string: "https://images.unsplash.com/photo-1418065460487-3e41a6c84dc5?w=600&q=80")),
    SoundIntention(title: "Comfort", palette: .ember, imageURL: URL(string: "https://images.unsplash.com/photo-1509316785289-025f5b846b35?w=600&q=80"))
  ]
}
