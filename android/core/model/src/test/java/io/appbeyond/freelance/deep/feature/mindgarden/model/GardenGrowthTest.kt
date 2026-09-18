package io.appbeyond.freelance.deep.feature.mindgarden.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/GardenGrowthTests.swift.
 *
 * The pure derivation from `(plant, sunlight)` — stage boundaries, the
 * within-stage arc, and the cumulative card fraction that never resets.
 */
class GardenGrowthTest {

  /** Seedling 0 / Young 200 / Mature 700 — the oak's seeded ladder. */
  private val oak = Plant.oakFixture

  @Test
  @DisplayName("Zero sunlight is the first form, arc empty")
  fun zeroSunlight() {
    val growth = GardenGrowth(plant = oak, sunlight = 0)

    assertEquals(0, growth.stageIndex)
    assertEquals("Oak Seedling", growth.stage.name)
    assertEquals("Young Oak", growth.nextStage?.name)
    assertFalse(growth.isFullyGrown)
    assertEquals(200, growth.sunlightToEvolve)
    assertEquals(0.0, growth.evolutionProgress)
  }

  @Test
  @DisplayName("One point short of a threshold stays in the earlier form")
  fun justBelowThreshold() {
    val growth = GardenGrowth(plant = oak, sunlight = 199)

    assertEquals(0, growth.stageIndex)
    assertTrue(abs(growth.evolutionProgress - 199.0 / 200.0) < 0.0001)
  }

  @Test
  @DisplayName("Reaching a threshold exactly evolves — and the banked figure keeps counting")
  fun exactThresholdEvolves() {
    val growth = GardenGrowth(plant = oak, sunlight = 200)

    assertEquals(1, growth.stageIndex)
    assertEquals("Young Oak", growth.stage.name)
    assertEquals("Mature Oak", growth.nextStage?.name)
    // The card's fraction is cumulative over the next threshold — 200/700,
    // not a reset-to-zero count.
    assertEquals(200, growth.sunlight)
    assertEquals(700, growth.sunlightToEvolve)
    // The halo arc, though, starts this stage afresh.
    assertEquals(0.0, growth.evolutionProgress)
  }

  @Test
  @DisplayName("Mid-stage arc measures within the current stage alone")
  fun midStageArc() {
    val growth = GardenGrowth(plant = oak, sunlight = 450)

    assertEquals(1, growth.stageIndex)
    // (450 − 200) / (700 − 200)
    assertTrue(abs(growth.evolutionProgress - 0.5) < 0.0001)
  }

  @Test
  @DisplayName("The final threshold is fully grown, arc complete")
  fun finalThreshold() {
    val growth = GardenGrowth(plant = oak, sunlight = 700)

    assertEquals(2, growth.stageIndex)
    assertTrue(growth.isFullyGrown)
    assertNull(growth.nextStage)
    assertNull(growth.sunlightToEvolve)
    assertEquals(1.0, growth.evolutionProgress)
  }

  @Test
  @DisplayName("Sunlight keeps banking past the final form without regressing anything")
  fun pastMax() {
    val growth = GardenGrowth(plant = oak, sunlight = 1_250)

    assertEquals(2, growth.stageIndex)
    assertTrue(growth.isFullyGrown)
    assertEquals(1.0, growth.evolutionProgress)
    assertEquals(1_250, growth.sunlight)
  }

  @Test
  @DisplayName("A single-stage plant is fully grown from its first ray")
  fun singleStage() {
    val bonsai = Plant(
      id = "bonsai",
      name = "Bonsai",
      tagline = "",
      stages = listOf(PlantStage(id = "bonsai-0", name = "Bonsai", threshold = 0)),
    )
    val growth = GardenGrowth(plant = bonsai, sunlight = 0)

    assertEquals(0, growth.stageIndex)
    assertTrue(growth.isFullyGrown)
    assertNull(growth.sunlightToEvolve)
    assertEquals(1.0, growth.evolutionProgress)
  }

  @Test
  @DisplayName("A plant with no authored stages reads as a bare seed, never crashes")
  fun emptyStages() {
    val bare = Plant(id = "bare", name = "Bare", tagline = "", stages = emptyList())
    val growth = GardenGrowth(plant = bare, sunlight = 40)

    assertEquals(0, growth.stageIndex)
    assertEquals("Bare", growth.stage.name)
    assertTrue(growth.isFullyGrown)
    assertEquals(1.0, growth.evolutionProgress)
  }
}
