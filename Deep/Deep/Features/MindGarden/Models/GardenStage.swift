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
  /// Stable identity: the garden is re-derived from live practice state on
  /// every body evaluation, so identity must not churn between derivations.
  var id: PlantKind { kind }
  let kind: PlantKind
  let name: String
  /// Streak days needed to reach this stage.
  let dayThreshold: Int
  /// Two-stop gradient for the tile backdrop, top-leading → bottom-trailing.
  let tint: [Color]
  let isUnlocked: Bool
}

extension GardenStage {
  /// The journey from first seedling to a settled canopy, with each plant
  /// unlocked by the longest streak the user has ever grown — never the
  /// current one, so growth never regresses ("nothing to fail"). The seedling
  /// is always awake: the garden greets you with life.
  static func journey(unlockedForLongestStreak days: Int) -> [GardenStage] {
    let unlocked = max(days, 1)
    return [
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
        tint: [.skyWash, GardenColor.meadow],
        isUnlocked: unlocked >= 7
      ),
      GardenStage(
        kind: .bloom,
        name: "Bloom",
        dayThreshold: 21,
        tint: [.blushPowder, .softLilac],
        isUnlocked: unlocked >= 21
      ),
      GardenStage(
        kind: .tree,
        name: "Willow",
        dayThreshold: 40,
        tint: [GardenColor.sage, .skyWash],
        isUnlocked: unlocked >= 40
      )
    ]
  }

  /// A sample journey for previews — a 12-day best streak, sprout reached.
  static let journey: [GardenStage] = journey(unlockedForLongestStreak: 12)
}
