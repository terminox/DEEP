package io.appbeyond.freelance.deep.feature.globalpause.earth

import org.junit.jupiter.api.Test
import java.math.BigInteger
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/Earth3D/NightSkyBackground.swift
 * (`NightSkyStarField` and its `SplitMix64`). iOS has no tests for it; these are new,
 * written from the iOS behaviour.
 *
 * What it guards: a seed always reproduces the same constellation — the very one iOS
 * draws for it — so the generator's wrapping UInt64 arithmetic is checked against an
 * independent unsigned reference built on BigInteger.
 */
class NightSkyStarFieldTest {

  private val mask = BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE)
  private val golden = BigInteger("9E3779B97F4A7C15", 16)
  private val mixA = BigInteger("BF58476D1CE4E5B9", 16)
  private val mixB = BigInteger("94D049BB133111EB", 16)

  /** Swift's `SplitMix64.next()` in unsigned 64-bit arithmetic: (new state, output). */
  private fun reference(state: BigInteger): Pair<BigInteger, BigInteger> {
    val s = state.add(golden).and(mask)
    var z = s
    z = z.xor(z.shiftRight(30)).multiply(mixA).and(mask)
    z = z.xor(z.shiftRight(27)).multiply(mixB).and(mask)
    return s to z.xor(z.shiftRight(31))
  }

  /** `UInt64(bitPattern: Int64(seed)) &+ 0x5EED`. */
  private fun iosState(seed: Int): BigInteger =
    BigInteger.valueOf(seed.toLong()).and(mask).add(BigInteger.valueOf(0x5EED)).and(mask)

  @Test
  fun splitMixMatchesAnUnsignedReference() {
    for (seed in listOf(1, 0, 42, -1, Int.MIN_VALUE, Int.MAX_VALUE)) {
      val rng = NightSkyStarField.SplitMix64(seed.toLong() + 0x5EED)
      var state = iosState(seed)
      repeat(16) {
        val (next, out) = reference(state)
        state = next
        assertEquals(out.toLong(), rng.next(), "seed $seed, draw $it")
      }
    }
  }

  @Test
  fun theFirstStarOfSeedOneIsTheReferencesTopTwentyFourBits() {
    val (_, first) = reference(iosState(1))
    val expectedX = first.shiftRight(40).toInt().toFloat() / (1 shl 24).toFloat()
    assertEquals(expectedX, NightSkyStarField.stars(seed = 1, count = 1).single().x)
  }

  @Test
  fun aSeedAlwaysReproducesTheSameField() {
    assertEquals(NightSkyStarField.stars(7, 200), NightSkyStarField.stars(7, 200))
    // A longer field extends the shorter one: draws are in a fixed order.
    assertEquals(NightSkyStarField.stars(7, 50), NightSkyStarField.stars(7, 200).take(50))
  }

  @Test
  fun differentSeedsDiffer() {
    assertNotEquals(NightSkyStarField.stars(7, 20), NightSkyStarField.stars(8, 20))
  }

  @Test
  fun everyFieldIsInRange() {
    val twoPi = 2f * PI_F
    for (star in NightSkyStarField.stars(seed = 3, count = 2000)) {
      for (unit in listOf(star.x, star.y, star.sizeT, star.brightT, star.tintT, star.twinkleT)) {
        assertTrue(unit >= 0f && unit < 1f, "unit $unit in $star")
      }
      assertTrue(star.phase >= 0f && star.phase <= twoPi, "phase in $star")
      assertTrue(star.rateJitter >= 0.6f && star.rateJitter <= 1.4f, "rateJitter in $star")
    }
  }

  @Test
  fun unitIsTheTopTwentyFourBits() {
    val rng = NightSkyStarField.SplitMix64(99)
    val peek = NightSkyStarField.SplitMix64(99)
    repeat(8) {
      val raw = peek.next()
      assertEquals((raw ushr 40).toFloat() / 16_777_216f, rng.unit())
    }
  }
}
