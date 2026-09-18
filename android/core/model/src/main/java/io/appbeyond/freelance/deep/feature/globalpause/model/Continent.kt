package io.appbeyond.freelance.deep.feature.globalpause.model

/**
 * The continents, as Global Pause names them.
 *
 * Declaration order *is* display order: the longitude of each continent's
 * centre, west to east, so a row of these read left to right reads the world
 * the way the globe turns. Antarctica sits last rather than at its centre —
 * it wraps every longitude, so it has no place in the sweep.
 *
 * North and South America are one case on purpose. "Americas" is how this
 * screen speaks about the world, and merging them keeps five names breathing
 * across the width of a phone.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Models/Continent.swift.
 */
enum class Continent {
  Americas,
  Europe,
  Africa,
  Asia,
  Oceania,
  Antarctica;

  /** The raw wire id — the lowercase form of the case name. */
  val id: String get() = name.lowercase()

  /** The name under the count. Sentence case; a caller that wants an
   * all-caps label uppercases it there. */
  val displayName: String
    get() = when (this) {
      Americas -> "Americas"
      Europe -> "Europe"
      Africa -> "Africa"
      Asia -> "Asia"
      Oceania -> "Oceania"
      Antarctica -> "Antarctica"
    }

  /** The name inside a sentence, for accessibility — "1,842 in the Americas". */
  val spokenName: String
    get() = if (this == Americas) "the Americas" else displayName

  companion object {
    /** Reads the server's continent codes (MaxMind's alphabet, which the API
     * speaks). The Americas answer to two of them. */
    fun fromIso(iso: String): Continent? = when (iso.uppercase()) {
      "NA", "SA" -> Americas
      "EU" -> Europe
      "AF" -> Africa
      "AS" -> Asia
      "OC" -> Oceania
      "AN" -> Antarctica
      else -> null
    }
  }
}
