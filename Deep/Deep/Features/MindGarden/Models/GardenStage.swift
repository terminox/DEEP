import SwiftUI

/// The silhouette a garden plant takes at a given point in the journey.
enum PlantKind: String, CaseIterable, Hashable {
  case seedling
  case sprout
  case bloom
  case tree
}

/// One milestone in the user's Mind Garden — a plant that unlocks and grows as
/// the practice streak deepens.
struct GardenStage: Identifiable, Hashable {
  let id = UUID()
  let kind: PlantKind
  let name: String
  /// Streak days needed to reach this stage.
  let dayThreshold: Int
  /// Two-stop gradient for the tile backdrop, top-leading → bottom-trailing.
  let tint: [Color]
  let isUnlocked: Bool
}

extension GardenStage {
  /// A sample journey from first seedling to a settled canopy.
  static let journey: [GardenStage] = [
    GardenStage(
      kind: .seedling,
      name: "Seedling",
      dayThreshold: 1,
      tint: [GardenColor.meadow, GardenColor.sage],
      isUnlocked: true
    ),
    GardenStage(
      kind: .sprout,
      name: "Sprout",
      dayThreshold: 7,
      tint: [DeepColor.skyWash, GardenColor.meadow],
      isUnlocked: true
    ),
    GardenStage(
      kind: .bloom,
      name: "Bloom",
      dayThreshold: 21,
      tint: [DeepColor.blushPowder, DeepColor.softLilac],
      isUnlocked: false
    ),
    GardenStage(
      kind: .tree,
      name: "Willow",
      dayThreshold: 40,
      tint: [GardenColor.sage, DeepColor.skyWash],
      isUnlocked: false
    )
  ]
}
