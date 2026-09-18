package io.appbeyond.freelance.deep.feature.mindgarden.model

/**
 * A plant's growth, derived purely from `(plant, sunlight)` — no stored stage,
 * no counter that resets. The stage is the last form on the ladder whose
 * cumulative threshold the banked sunlight has reached; the card's fraction is
 * the *cumulative* figure over the next threshold (so the number never resets
 * on an evolution), and the halo's arc is the fraction of the way through the
 * current stage alone.
 *
 * Ported from Deep/Deep/Features/MindGarden/Models/GardenGrowth.swift. The
 * structure is unchanged — this is a plain derivation with no clock, no
 * networking, nothing iOS-specific to swap out.
 */
data class GardenGrowth(
  val plant: Plant,
  /** Total sunlight this plant has drunk over its whole life, across stages. */
  val sunlight: Int,
) {
  /** Index of the form the plant currently holds. */
  val stageIndex: Int
    get() {
      var index = 0
      for ((offset, stage) in plant.stages.withIndex()) {
        if (stage.threshold <= sunlight) index = offset
      }
      return index
    }

  /** The form the plant currently holds. A plant with no authored stages yet
   * reads as a bare seed rather than crashing the derivation. */
  val stage: PlantStage
    get() = plant.stages.getOrNull(stageIndex)
      ?: PlantStage(id = "${plant.id}-seed", name = plant.name, threshold = 0)

  /** The form this plant grows into next — named by the card, never shown —
   * or `null` once fully grown. */
  val nextStage: PlantStage?
    get() = plant.stages.getOrNull(stageIndex + 1)

  val isFullyGrown: Boolean get() = nextStage == null

  /** Cumulative sunlight the next form asks for — the card's denominator in
   * "X/Y to <next form>". `null` once fully grown. */
  val sunlightToEvolve: Int? get() = nextStage?.threshold

  /** Fraction of the way through the CURRENT stage, clamped to 0...1 — the
   * halo's arc. A fully grown plant reads as complete. */
  val evolutionProgress: Double
    get() {
      val next = nextStage ?: return 1.0
      val base = stage.threshold
      val span = next.threshold - base
      if (span <= 0) return 1.0
      return ((sunlight - base).toDouble() / span).coerceIn(0.0, 1.0)
    }

  companion object {
    /** A mid-journey oak — Young, 240 banked toward the Mature form. */
    val sample = GardenGrowth(plant = Plant.oakFixture, sunlight = 240)

    /** A brand-new garden — the seed has just been planted. */
    val sprouting = GardenGrowth(plant = Plant.oakFixture, sunlight = 0)

    /** The ceiling state: the oak has reached its final form. */
    val fullyGrown = GardenGrowth(plant = Plant.oakFixture, sunlight = 700)
  }
}
