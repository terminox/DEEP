import Foundation

/// One of the Mind Trees a person can pick at the end of onboarding — a small
/// living emblem of how they'd like to grow. At runtime these are the
/// admin-managed plants served by `GET /onboarding/config`, and the pick seeds
/// the Mind Garden's selection.
///
/// `imageURL` is the plant's picker artwork; `palette` keeps the on-brand
/// gradient underneath while the image loads, when it fails, or offline.
struct MindTree: Identifiable, Hashable {
  let id: String
  let name: String
  let tagline: String
  let imageURL: URL?
  let palette: ArtworkPalette
}

extension MindTree {
  /// Bundled sample trees, for previews and `MockOnboardingRemote` only. These
  /// are never shown in the app: they share the real plants' ids, names and
  /// taglines, so falling back to them would disguise an unreachable backend
  /// as a working one. See `OnboardingConfig`.
  static let all: [MindTree] = [
    MindTree(
      id: "oak",
      name: "Oak",
      tagline: "Steady & Strong",
      imageURL: URL(string: "https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=800&q=80&fm=jpg&fit=crop"),
      palette: .tide
    ),
    MindTree(
      id: "sakura",
      name: "Sakura",
      tagline: "Gentle & Open",
      imageURL: URL(string: "https://images.unsplash.com/photo-1522383225653-ed111181a951?w=800&q=80&fm=jpg&fit=crop"),
      palette: .bloom
    ),
    MindTree(
      id: "lotus",
      name: "Lotus",
      tagline: "Calm & Mindful",
      imageURL: URL(string: "https://images.unsplash.com/photo-1474557157379-8aa74a6ef541?w=800&q=80&fm=jpg&fit=crop"),
      palette: .mist
    ),
    MindTree(
      id: "orange",
      name: "Orange",
      tagline: "Warm & Joyful",
      imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Bitter_orange_-_Citrus_%C3%97_aurantium_03.jpg/500px-Bitter_orange_-_Citrus_%C3%97_aurantium_03.jpg"),
      palette: .ember
    ),
  ]
}
