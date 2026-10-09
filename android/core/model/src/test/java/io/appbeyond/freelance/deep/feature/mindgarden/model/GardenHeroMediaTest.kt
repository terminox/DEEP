package io.appbeyond.freelance.deep.feature.mindgarden.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

/**
 * The garden home's hero choice, ported from `MindGardenHomeView.heroMedia`
 * (no iOS test covers it).
 */
class GardenHeroMediaTest {

  private fun oakWithMatureVideo(): Plant {
    val stages = Plant.oakFixture.stages.toMutableList()
    stages[2] = stages[2].copy(
      heroVideoUrl = "https://cdn.example/oak-mature.mp4",
      mascotUrl = "https://cdn.example/oak-mature.png",
    )
    return Plant.oakFixture.copy(stages = stages)
  }

  @Test
  @DisplayName("A garden still loading plays the bundled oak")
  fun loadingIsBundledOak() {
    assertEquals(GardenHeroMedia.BundledOak, GardenHeroMedia.forGrowth(null))
  }

  @Test
  @DisplayName("An oak stage without footage keeps the bundled loop")
  fun oakWithoutFootage() {
    assertEquals(GardenHeroMedia.BundledOak, GardenHeroMedia.forGrowth(GardenGrowth.sample))
  }

  @Test
  @DisplayName("An oak stage with footage plays it, the portrait as poster")
  fun oakWithFootage() {
    val growth = GardenGrowth(plant = oakWithMatureVideo(), sunlight = 700)

    assertEquals(
      GardenHeroMedia.RemoteVideo(
        url = "https://cdn.example/oak-mature.mp4",
        posterUrl = "https://cdn.example/oak-mature.png",
      ),
      GardenHeroMedia.forGrowth(growth),
    )
  }

  @Test
  @DisplayName("Another plant always goes remote, preferring the painted background as poster")
  fun otherPlantGoesRemote() {
    val stages = Plant.sakuraFixture.stages.toMutableList()
    stages[0] = stages[0].copy(mascotUrl = "portrait.png", mascotBgUrl = "painted.png")
    val sakura = Plant.sakuraFixture.copy(stages = stages)

    assertEquals(
      GardenHeroMedia.RemoteVideo(url = null, posterUrl = "painted.png"),
      GardenHeroMedia.forGrowth(GardenGrowth(plant = sakura, sunlight = 0)),
    )
    assertEquals(
      GardenHeroMedia.RemoteVideo(url = null, posterUrl = null),
      GardenHeroMedia.forGrowth(GardenGrowth(plant = Plant.lotusFixture, sunlight = 0)),
    )
  }
}
