import Testing
import Foundation
@testable import Deep

/// The pure derivation from `(plant, sunlight)` — stage boundaries, the
/// within-stage arc, and the cumulative card fraction that never resets.
@MainActor
struct GardenGrowthTests {
  /// Seedling 0 / Young 200 / Mature 700 — the oak's seeded ladder.
  private let oak = Plant.oakFixture

  @Test("Zero sunlight is the first form, arc empty")
  func zeroSunlight() {
    let growth = GardenGrowth(plant: oak, sunlight: 0)

    #expect(growth.stageIndex == 0)
    #expect(growth.stage.name == "Oak Seedling")
    #expect(growth.nextStage?.name == "Young Oak")
    #expect(growth.isFullyGrown == false)
    #expect(growth.pointsToEvolve == 200)
    #expect(growth.evolutionProgress == 0)
  }

  @Test("One point short of a threshold stays in the earlier form")
  func justBelowThreshold() {
    let growth = GardenGrowth(plant: oak, sunlight: 199)

    #expect(growth.stageIndex == 0)
    #expect(abs(growth.evolutionProgress - 199.0 / 200.0) < 0.0001)
  }

  @Test("Reaching a threshold exactly evolves — and the banked figure keeps counting")
  func exactThresholdEvolves() {
    let growth = GardenGrowth(plant: oak, sunlight: 200)

    #expect(growth.stageIndex == 1)
    #expect(growth.stage.name == "Young Oak")
    #expect(growth.nextStage?.name == "Mature Oak")
    // The card's fraction is cumulative over the next threshold — 200/700,
    // not a reset-to-zero count.
    #expect(growth.sunlight == 200)
    #expect(growth.pointsToEvolve == 700)
    // The halo arc, though, starts this stage afresh.
    #expect(growth.evolutionProgress == 0)
  }

  @Test("Mid-stage arc measures within the current stage alone")
  func midStageArc() {
    let growth = GardenGrowth(plant: oak, sunlight: 450)

    #expect(growth.stageIndex == 1)
    // (450 − 200) / (700 − 200)
    #expect(abs(growth.evolutionProgress - 0.5) < 0.0001)
  }

  @Test("The final threshold is fully grown, arc complete")
  func finalThreshold() {
    let growth = GardenGrowth(plant: oak, sunlight: 700)

    #expect(growth.stageIndex == 2)
    #expect(growth.isFullyGrown)
    #expect(growth.nextStage == nil)
    #expect(growth.pointsToEvolve == nil)
    #expect(growth.evolutionProgress == 1)
  }

  @Test("Sunlight keeps banking past the final form without regressing anything")
  func pastMax() {
    let growth = GardenGrowth(plant: oak, sunlight: 1_250)

    #expect(growth.stageIndex == 2)
    #expect(growth.isFullyGrown)
    #expect(growth.evolutionProgress == 1)
    #expect(growth.sunlight == 1_250)
  }

  @Test("A single-stage plant is fully grown from its first ray")
  func singleStage() {
    let bonsai = Plant(
      id: "bonsai", name: "Bonsai", tagline: "",
      stages: [PlantStage(id: "bonsai-0", name: "Bonsai", threshold: 0)]
    )
    let growth = GardenGrowth(plant: bonsai, sunlight: 0)

    #expect(growth.stageIndex == 0)
    #expect(growth.isFullyGrown)
    #expect(growth.pointsToEvolve == nil)
    #expect(growth.evolutionProgress == 1)
  }

  @Test("A plant with no authored stages reads as a bare seed, never crashes")
  func emptyStages() {
    let bare = Plant(id: "bare", name: "Bare", tagline: "", stages: [])
    let growth = GardenGrowth(plant: bare, sunlight: 40)

    #expect(growth.stageIndex == 0)
    #expect(growth.stage.name == "Bare")
    #expect(growth.isFullyGrown)
    #expect(growth.evolutionProgress == 1)
  }
}
