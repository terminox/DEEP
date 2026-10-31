package io.appbeyond.freelance.deep.feature.compassion.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.random.Random
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The rising hearts' count ladder, rolled ranges and curves, checked against
 * the numbers in iOS's RisingHearts.swift (which has no test of its own).
 */
class RisingHeartsFieldTest {

  private val heart = RisingHeart(
    delay = 0.25,
    life = 2.0,
    size = 30.0,
    tone = HeartTone.MoonCream,
    launch = 10.0,
    spread = 100.0,
    height = 400.0,
    swayWidth = 20.0,
    phase = 0.0,
  )

  @Test
  @DisplayName("the count grows on a log scale and caps at 24")
  fun countLadder() {
    assertEquals(5, RisingHeartsField.count(0))
    assertEquals(5, RisingHeartsField.count(1))
    assertEquals(9, RisingHeartsField.count(2))
    assertEquals(18, RisingHeartsField.count(10))
    assertEquals(24, RisingHeartsField.count(30))
    assertEquals(24, RisingHeartsField.count(10_000))
  }

  @Test
  @DisplayName("a seeded roll is reproducible and stays inside iOS's ranges")
  fun rollRanges() {
    val first = RisingHeartsField.roll(24, Random(7))
    assertEquals(first, RisingHeartsField.roll(24, Random(7)))
    assertEquals(24, first.size)
    first.forEachIndexed { index, h ->
      assertTrue(h.delay >= index * 0.07 && h.delay <= index * 0.07 + 0.12)
      assertTrue(h.life in 1.8..2.5)
      assertTrue(h.size in 16.0..34.0)
      assertTrue(h.launch in -70.0..70.0)
      assertTrue(h.spread in -120.0..120.0)
      assertTrue(h.height in 220.0..520.0)
      assertTrue(h.swayWidth in 8.0..26.0)
      assertTrue(h.phase in 0.0..1.0)
    }
  }

  @Test
  @DisplayName("moon-white outweighs the blush and peach hearts")
  fun toneWeights() {
    val tones = RisingHeartsField.roll(6_000, Random(1)).groupingBy { it.tone }.eachCount()
    val cream = tones.getValue(HeartTone.MoonCream)
    assertTrue(cream in 3_700..4_300, "moonCream $cream of 6000")
    assertTrue(tones.getValue(HeartTone.BlushPowder) in 850..1_150)
    assertTrue(tones.getValue(HeartTone.PeachCloud) in 850..1_150)
  }

  @Test
  @DisplayName("a heart draws only between its delay and the end of its life")
  fun liveWindow() {
    assertNull(RisingHeartsField.pose(heart, 0.24))
    assertNotNull(RisingHeartsField.pose(heart, 0.25))
    assertNotNull(RisingHeartsField.pose(heart, 2.25))
    assertNull(RisingHeartsField.pose(heart, 2.26))
    assertEquals(2.25, RisingHeartsField.duration(listOf(heart, heart.copy(delay = 0.0))))
    assertEquals(0.0, RisingHeartsField.duration(emptyList()))
  }

  @Test
  @DisplayName("it leaves from the launch point, small and unseen, and blooms in")
  fun liftOff() {
    val start = RisingHeartsField.pose(heart, 0.25)!!
    assertEquals(10.0, start.x, 1e-9)
    assertEquals(0.0, start.y, 1e-9)
    assertEquals(0.0, start.opacity, 1e-9)
    assertEquals(30.0 * 0.4, start.size, 1e-9)

    // 8% in: fully opaque; 12% in: full size.
    assertEquals(1.0, RisingHeartsField.pose(heart, 0.25 + 2.0 * 0.08)!!.opacity, 1e-9)
    assertEquals(30.0, RisingHeartsField.pose(heart, 0.25 + 2.0 * 0.12)!!.size, 1e-9)
  }

  @Test
  @DisplayName("it rises on 1 − (1 − t)^2.2 and fades out over its second half")
  fun riseAndFade() {
    val half = RisingHeartsField.pose(heart, 0.25 + 1.0)!!
    val lift = 1 - Math.pow(0.5, 2.2)
    assertEquals(-400.0 * lift, half.y, 1e-9)
    assertEquals(1.0, half.opacity, 1e-9)

    val threeQuarters = RisingHeartsField.pose(heart, 0.25 + 1.5)!!
    assertEquals(0.5, threeQuarters.opacity, 1e-9)

    val end = RisingHeartsField.pose(heart, 2.25)!!
    assertEquals(-400.0, end.y, 1e-9)
    assertEquals(0.0, end.opacity, 1e-9)
    assertTrue(kotlin.math.abs(end.rotation) <= 0.18)
  }
}
