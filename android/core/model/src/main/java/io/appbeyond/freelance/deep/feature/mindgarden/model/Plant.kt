package io.appbeyond.freelance.deep.feature.mindgarden.model

/**
 * A plant from the admin-managed catalog — the thing sunlight grows. The
 * user's selected plant plus its banked sunlight derive [GardenGrowth];
 * unselected plants keep their own sunlight and resume where they left off.
 *
 * Ported from Deep/Deep/Features/MindGarden/Models/Plant.swift. `imageURL`
 * and `palette` (picker card art) stay on the iOS side, same reasoning as
 * [PlantStage]'s dropped portrait fields — presentation/networking concerns,
 * not the pure growth derivation this module carries.
 */
data class Plant(
  val id: String,
  val name: String,
  val tagline: String,
  /** The growth ladder in evolution order; thresholds strictly increasing
   * from 0. Validated server-side; the derivation tolerates anything. */
  val stages: List<PlantStage>,
) {
  companion object {
    /** The oak as the seed data defines it (Seedling 0 / Young 200 / Mature
     * 700, the cumulative reading of the old 200/500 ladder). */
    val oakFixture = Plant(
      id = "oak",
      name = "Oak",
      tagline = "Steady, patient strength",
      stages = listOf(
        PlantStage(id = "oak-stage-0", name = "Oak Seedling", threshold = 0),
        PlantStage(id = "oak-stage-1", name = "Young Oak", threshold = 200),
        PlantStage(id = "oak-stage-2", name = "Mature Oak", threshold = 700),
      ),
    )

    val sakuraFixture = Plant(
      id = "sakura",
      name = "Sakura",
      tagline = "Beauty in every passing season",
      stages = listOf(
        PlantStage(id = "sakura-stage-0", name = "Sakura Sprout", threshold = 0),
        PlantStage(id = "sakura-stage-1", name = "Budding Sakura", threshold = 150),
        PlantStage(id = "sakura-stage-2", name = "Blossoming Sakura", threshold = 450),
        PlantStage(id = "sakura-stage-3", name = "Full-Bloom Sakura", threshold = 900),
      ),
    )

    val lotusFixture = Plant(
      id = "lotus",
      name = "Lotus",
      tagline = "Calm rising from still water",
      stages = listOf(
        PlantStage(id = "lotus-stage-0", name = "Lotus Seed", threshold = 0),
        PlantStage(id = "lotus-stage-1", name = "Rising Lotus", threshold = 250),
        PlantStage(id = "lotus-stage-2", name = "Open Lotus", threshold = 600),
      ),
    )

    /** The mock catalog — the four seeded slugs minus premium, matching what
     * `GET /garden/plants` serves in seed data. */
    val fixtures: List<Plant> = listOf(oakFixture, sakuraFixture, lotusFixture)
  }
}
