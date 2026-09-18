package io.appbeyond.freelance.deep.feature.globalpause.model

import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/ContinentRollTests.swift.
 *
 * The fold behind the live session's continent row. What it guards: the row
 * is a map, not a leaderboard — its order must come from geography and never
 * from the counts, or columns reshuffle underneath someone who is meditating.
 */
class ContinentRollTest {

  @Test
  fun ordersWestToEastRegardlessOfSize() {
    val row = ContinentPresence.row(
      mapOf("OC" to 9000, "AS" to 1, "AF" to 500, "EU" to 20, "NA" to 3),
    )
    assertEquals(
      listOf(Continent.Americas, Continent.Europe, Continent.Africa, Continent.Asia, Continent.Oceania),
      row.map { it.continent },
    )
  }

  @Test
  fun mergesTheTwoAmericas() {
    val row = ContinentPresence.row(mapOf("NA" to 604, "SA" to 199))
    assertEquals(1, row.size)
    assertEquals(Continent.Americas, row[0].continent)
    assertEquals(803, row[0].count)
  }

  /** A continent nobody is in has nothing to say — a nought beside its name
   * would read as an absence rather than a fact. */
  @Test
  fun dropsEmptyAndUnknownContinents() {
    val row = ContinentPresence.row(mapOf("AS" to 12, "AF" to 0, "EU" to -3, "XX" to 99))
    assertEquals(listOf(Continent.Asia), row.map { it.continent })
    assertTrue(ContinentPresence.row(emptyMap()).isEmpty())
  }

  @Test
  fun antarcticaComesLastWhenSomeoneIsThere() {
    val row = ContinentPresence.row(mapOf("AN" to 1, "AS" to 40, "NA" to 7))
    assertEquals(
      listOf(Continent.Americas, Continent.Asia, Continent.Antarctica),
      row.map { it.continent },
    )
  }

  @Test
  fun readsCodesCaseInsensitivelyAndRefusesJunk() {
    assertEquals(Continent.Asia, Continent.fromIso("as"))
    assertEquals(Continent.Americas, Continent.fromIso("sa"))
    assertNull(Continent.fromIso("ZZ"))
    assertNull(Continent.fromIso(""))
  }

  /** "the Americas" inside a sentence, "Americas" as a label. */
  @Test
  fun spokenNameSuitsASentence() {
    assertEquals("the Americas", Continent.Americas.spokenName)
    assertEquals("Americas", Continent.Americas.displayName)
    assertEquals("Asia", Continent.Asia.spokenName)
  }
}
