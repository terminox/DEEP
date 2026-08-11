import Foundation

/// The oak's evolution ladder. Declaration order is growth order — each stage
/// evolves into the next once enough growth points are banked.
enum OakStage: Int, CaseIterable, Identifiable {
  case seedling
  case young
  case mature

  var id: Int { rawValue }

  /// The form this stage grows into, or `nil` once fully grown.
  var next: OakStage? { OakStage(rawValue: rawValue + 1) }

  var displayName: String {
    switch self {
    case .seedling: "Oak Seedling"
    case .young: "Young Oak"
    case .mature: "Mature Oak"
    }
  }

  /// Asset-catalog image for this stage's artwork.
  var imageName: String {
    switch self {
    case .seedling: "MindGardenOakSeedling"
    case .young: "MindGardenOakYoung"
    case .mature: "MindGardenOakMature"
    }
  }

  /// Growth points needed to evolve out of this stage; `nil` once fully grown.
  var pointsToEvolve: Int? {
    switch self {
    case .seedling: 200
    case .young: 500
    case .mature: nil
    }
  }
}

/// A snapshot of the selected plant's growth — which form it's in and the
/// points banked toward the next evolution. Completed sessions will feed this;
/// for now it's sample data only, not yet persisted.
struct GardenGrowth {
  var stage: OakStage
  /// Points earned within the current stage.
  var points: Int

  var nextStage: OakStage? { stage.next }
  var pointsToEvolve: Int? { stage.pointsToEvolve }
  var isFullyGrown: Bool { nextStage == nil }

  /// Points still to grow before the next evolution; `nil` once fully grown.
  var pointsRemaining: Int? {
    pointsToEvolve.map { max(0, $0 - points) }
  }

  /// Fraction of the way to the next evolution, clamped to 0...1.
  /// A fully grown plant reads as complete.
  var evolutionProgress: Double {
    guard let goal = pointsToEvolve, goal > 0 else { return 1 }
    return min(1, Double(points) / Double(goal))
  }
}

extension GardenGrowth {
  static let sample = GardenGrowth(stage: .young, points: 240)

  /// A brand-new garden — the seed has just been planted.
  static let sprouting = GardenGrowth(stage: .seedling, points: 0)

  /// The ceiling state: the oak has reached its final form.
  static let fullyGrown = GardenGrowth(stage: .mature, points: 0)
}
