import Foundation

/// One form on a plant's growth ladder, as the admin-managed catalog defines
/// it. `threshold` is the CUMULATIVE sunlight required to *reach* this form —
/// the first stage is always 0 — so the card's banked figure never resets on
/// an evolution. Asset URLs are optional: fixture stages and half-authored
/// catalog entries simply fall back to gradient artwork.
struct PlantStage: Identifiable, Equatable, Codable {
  let id: String
  /// The form's name, e.g. "Young Oak" — spoken by the growth card, never
  /// pictured until reached.
  let name: String
  /// Cumulative sunlight needed to reach this form; strictly increasing along
  /// the ladder, first always 0.
  let threshold: Int
  /// The form's portrait, background removed.
  var mascotURL: URL? = nil
  /// The portrait on its painted background, when one exists.
  var mascotBgURL: URL? = nil
  /// The looping hero video for this form, when one exists.
  var heroVideoURL: URL? = nil
}

/// A plant from the admin-managed catalog — the thing sunlight grows. The
/// user's selected plant plus its banked sunlight derive `GardenGrowth`;
/// unselected plants keep their own sunlight (see
/// `GardenStore.sunlightByPlant`) and resume where they left off.
struct Plant: Identifiable, Equatable, Codable {
  let id: String
  let name: String
  let tagline: String
  /// Picker card art.
  var imageURL: URL? = nil
  var palette: ArtworkPalette = .mist
  /// The growth ladder in evolution order; thresholds strictly increasing
  /// from 0. Validated server-side; the derivation tolerates anything.
  var stages: [PlantStage]
}

// The palette already carries a String raw value; declaring the conformance is
// all `Plant`'s persistence blob needs.
extension ArtworkPalette: Codable {}

// MARK: - Fixtures

extension Plant {
  /// The oak as the seed data defines it (Seedling 0 / Young 200 / Mature 700,
  /// the cumulative reading of the old 200/500 ladder). Mascot art comes from
  /// the server in the live app, so the fixture's portraits stay nil and render
  /// as gradients; the mature hero video is the bundled loop the garden home
  /// already ships.
  static let oakFixture = Plant(
    id: "oak",
    name: "Oak",
    tagline: "Steady, patient strength",
    palette: .mist,
    stages: [
      PlantStage(id: "oak-stage-0", name: "Oak Seedling", threshold: 0),
      PlantStage(id: "oak-stage-1", name: "Young Oak", threshold: 200),
      PlantStage(
        id: "oak-stage-2",
        name: "Mature Oak",
        threshold: 700,
        heroVideoURL: Bundle.main.url(forResource: "deep_oak_mature", withExtension: "mp4")
      ),
    ]
  )

  static let sakuraFixture = Plant(
    id: "sakura",
    name: "Sakura",
    tagline: "Beauty in every passing season",
    palette: .bloom,
    stages: [
      PlantStage(id: "sakura-stage-0", name: "Sakura Sprout", threshold: 0),
      PlantStage(id: "sakura-stage-1", name: "Budding Sakura", threshold: 150),
      PlantStage(id: "sakura-stage-2", name: "Blossoming Sakura", threshold: 450),
      PlantStage(id: "sakura-stage-3", name: "Full-Bloom Sakura", threshold: 900),
    ]
  )

  static let lotusFixture = Plant(
    id: "lotus",
    name: "Lotus",
    tagline: "Calm rising from still water",
    palette: .veil,
    stages: [
      PlantStage(id: "lotus-stage-0", name: "Lotus Seed", threshold: 0),
      PlantStage(id: "lotus-stage-1", name: "Rising Lotus", threshold: 250),
      PlantStage(id: "lotus-stage-2", name: "Open Lotus", threshold: 600),
    ]
  )

  /// The mock catalog — the four seeded slugs minus premium, matching what
  /// `GET /garden/plants` serves in seed data.
  static let fixtures: [Plant] = [oakFixture, sakuraFixture, lotusFixture]
}
