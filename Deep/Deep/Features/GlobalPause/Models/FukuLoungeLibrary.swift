import Foundation

/// Mock programme for Fuku's Lounge. No networking, no audio — just enough
/// shape for the lounge to mirror the home feed while the real set list waits
/// on the combined pause states. Everything here is display-only; the lounge
/// renders it inert.
enum FukuLoungeLibrary {
  /// "Made for the floor" — Fuku's picks for whoever just wandered in.
  static let madeForTheFloor: [SoundCollection] = [
    SoundCollection(
      title: "Tape Hiss",
      subtitle: "Warm dust on every loop",
      palette: .dusk,
      imageURL: URL(string: "https://images.unsplash.com/photo-1483412033650-1015ddeb83d1?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Side B Sunset", duration: 4 * 60 + 32),
        SoundTrack(title: "Worn Ribbon", duration: 3 * 60 + 58),
        SoundTrack(title: "Dust Bloom", duration: 5 * 60 + 12)
      ]
    ),
    SoundCollection(
      title: "Rainy Window",
      subtitle: "Beats behind the glass",
      palette: .tide,
      imageURL: URL(string: "https://images.unsplash.com/photo-1428592953211-077101b2021b?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Streetlight Drizzle", duration: 4 * 60 + 6),
        SoundTrack(title: "Umbrella Sway", duration: 3 * 60 + 44),
        SoundTrack(title: "Last Bus Home", duration: 5 * 60 + 20)
      ]
    ),
    SoundCollection(
      title: "Low Lamplight",
      subtitle: "Chords for a dim room",
      palette: .ember,
      imageURL: URL(string: "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Amber Hum", duration: 4 * 60 + 48),
        SoundTrack(title: "Slow Filament", duration: 3 * 60 + 36),
        SoundTrack(title: "Shade Down", duration: 5 * 60 + 2)
      ]
    ),
    SoundCollection(
      title: "Midnight Kitchen",
      subtitle: "Quiet grooves after hours",
      palette: .bloom,
      imageURL: URL(string: "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Kettle Steam", duration: 3 * 60 + 52),
        SoundTrack(title: "Two AM Toast", duration: 4 * 60 + 14),
        SoundTrack(title: "Fridge Light", duration: 4 * 60 + 40)
      ]
    )
  ]

  /// "Tonight's rotation" — the crates Fuku is pulling from on air.
  static let tonightsRotation: [SoundCollection] = [
    SoundCollection(
      title: "Vinyl Dusk",
      subtitle: "Crackle from the deep crates",
      palette: .dusk,
      imageURL: URL(string: "https://images.unsplash.com/photo-1461360228754-6e81c478b882?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Needle Drop", duration: 4 * 60 + 20),
        SoundTrack(title: "Inner Groove", duration: 5 * 60 + 8),
        SoundTrack(title: "Runout Etch", duration: 3 * 60 + 46)
      ]
    ),
    SoundCollection(
      title: "Neon Drift",
      subtitle: "City glow at walking pace",
      palette: .aurora,
      imageURL: URL(string: "https://images.unsplash.com/photo-1519608487953-e999c86e7455?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Crosswalk Shimmer", duration: 4 * 60 + 2),
        SoundTrack(title: "Vending Glow", duration: 3 * 60 + 54),
        SoundTrack(title: "Alley Echo", duration: 5 * 60 + 16)
      ]
    ),
    SoundCollection(
      title: "Paper Moon",
      subtitle: "Soft keys for late letters",
      palette: .dawn,
      imageURL: URL(string: "https://images.unsplash.com/photo-1532767153582-b1a0e5145009?w=600&q=80"),
      tracks: [
        SoundTrack(title: "Ink and Hum", duration: 4 * 60 + 26),
        SoundTrack(title: "Margin Notes", duration: 3 * 60 + 38),
        SoundTrack(title: "Fold and Seal", duration: 5 * 60 + 4)
      ]
    )
  ]

  /// The lounge's "Explore" moods — one grid tile per crate.
  static let moods: [PauseCategory] = [
    PauseCategory(id: "late-night", slug: "late-night", title: "Late night", collections: [madeForTheFloor[3]]),
    PauseCategory(id: "rainy-loops", slug: "rainy-loops", title: "Rainy loops", collections: [madeForTheFloor[1]]),
    PauseCategory(id: "tape-vinyl", slug: "tape-vinyl", title: "Tape & vinyl", collections: [tonightsRotation[0]]),
    PauseCategory(id: "slow-beats", slug: "slow-beats", title: "Slow beats", collections: [tonightsRotation[2]])
  ]
}
