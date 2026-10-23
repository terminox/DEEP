package io.appbeyond.freelance.deep.feature.mindgarden.model

/**
 * What the garden home's stretchy hero plays.
 *
 * Ported from the private `heroMedia` choice in
 * Deep/Deep/Features/MindGarden/Components/MindGardenHomeView.swift, lifted
 * here so the rule is tested rather than buried in a composable.
 */
sealed interface GardenHeroMedia {

  /** The mature-oak loop that ships inside the app. */
  data object BundledOak : GardenHeroMedia

  /**
   * The current stage's own footage, with its portrait as the poster. [url]
   * may be null — a stage with art but no video shows the poster alone.
   */
  data class RemoteVideo(val url: String?, val posterUrl: String?) : GardenHeroMedia

  companion object {
    /** The plant id whose bundled loop backs the flagship scene. */
    const val OAK_PLANT_ID = "oak"

    /**
     * The hero for [growth]: the stage's remote video with a poster, except
     * the oak keeps the bundled loop wherever the catalog has no footage for
     * its stage — and while the garden is still loading (null growth) — so the
     * flagship scene, and every preview on fixtures, never goes flat.
     */
    fun forGrowth(growth: GardenGrowth?): GardenHeroMedia {
      if (growth == null) return BundledOak
      val stage = growth.stage
      if (stage.heroVideoUrl == null && growth.plant.id == OAK_PLANT_ID) return BundledOak
      return RemoteVideo(
        url = stage.heroVideoUrl,
        posterUrl = stage.mascotBgUrl ?: stage.mascotUrl,
      )
    }
  }
}
