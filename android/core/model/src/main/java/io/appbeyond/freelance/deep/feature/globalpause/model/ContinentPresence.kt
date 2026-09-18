package io.appbeyond.freelance.deep.feature.globalpause.model

/**
 * One continent's share of the room — a line of the world's roll.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Models/Continent.swift.
 */
data class ContinentPresence(
  val continent: Continent,
  val count: Int,
) {
  val id: Continent get() = continent

  companion object {
    /**
     * Folds a wire tally (`{"AS": 1842, "NA": 500, "SA": 303, …}`) into the
     * display order, merging the two Americas.
     *
     * Empty continents are dropped rather than shown as zero: a continent
     * with nobody in it has nothing to say, and a nought beside its name
     * reads as an absence rather than a fact. One lighting up mid-session
     * simply arrives.
     */
    fun row(byContinentIso: Map<String, Int>): List<ContinentPresence> {
      val totals = mutableMapOf<Continent, Int>()
      for ((iso, count) in byContinentIso) {
        if (count <= 0) continue
        val continent = Continent.fromIso(iso) ?: continue
        totals[continent] = (totals[continent] ?: 0) + count
      }
      return Continent.entries.mapNotNull { continent ->
        totals[continent]?.let { ContinentPresence(continent, it) }
      }
    }
  }
}
