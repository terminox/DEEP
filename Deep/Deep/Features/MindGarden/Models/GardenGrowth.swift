import Foundation

/// A plant's growth, derived purely from `(plant, sunlight)` — no stored stage,
/// no counter that resets. The stage is the last form on the ladder whose
/// cumulative threshold the banked sunlight has reached; the card's fraction is
/// the *cumulative* figure over the next threshold (so the number never resets
/// on an evolution), and the halo's arc is the fraction of the way through the
/// current stage alone.
struct GardenGrowth: Equatable {
  var plant: Plant
  /// Total sunlight this plant has drunk over its whole life, across stages.
  var sunlight: Int

  /// Index of the form the plant currently holds.
  var stageIndex: Int {
    var index = 0
    for (offset, stage) in plant.stages.enumerated() where stage.threshold <= sunlight {
      index = offset
    }
    return index
  }

  /// The form the plant currently holds. A plant with no authored stages yet
  /// reads as a bare seed rather than crashing the derivation.
  var stage: PlantStage {
    plant.stages.indices.contains(stageIndex)
      ? plant.stages[stageIndex]
      : PlantStage(id: "\(plant.id)-seed", name: plant.name, threshold: 0)
  }

  /// The form this plant grows into next — named by the card, never shown —
  /// or `nil` once fully grown.
  var nextStage: PlantStage? {
    let next = stageIndex + 1
    return plant.stages.indices.contains(next) ? plant.stages[next] : nil
  }

  var isFullyGrown: Bool { nextStage == nil }

  /// Cumulative sunlight the next form asks for — the card's denominator in
  /// "X/Y to <next form>". `nil` once fully grown.
  var sunlightToEvolve: Int? { nextStage?.threshold }

  /// Fraction of the way through the CURRENT stage, clamped to 0...1 — the
  /// halo's arc. A fully grown plant reads as complete.
  var evolutionProgress: Double {
    guard let next = nextStage else { return 1 }
    let base = stage.threshold
    let span = next.threshold - base
    guard span > 0 else { return 1 }
    return min(1, max(0, Double(sunlight - base) / Double(span)))
  }
}

extension GardenGrowth {
  /// A mid-journey oak — Young, 240 banked toward the Mature form.
  static let sample = GardenGrowth(plant: .oakFixture, sunlight: 240)

  /// A brand-new garden — the seed has just been planted.
  static let sprouting = GardenGrowth(plant: .oakFixture, sunlight: 0)

  /// The ceiling state: the oak has reached its final form.
  static let fullyGrown = GardenGrowth(plant: .oakFixture, sunlight: 700)
}
