package io.appbeyond.freelance.deep.feature.compassion.model

import kotlin.math.PI
import kotlin.math.log2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.random.Random

/** A rising heart's colour, by role — the app maps it onto the palette. */
enum class HeartTone { MoonCream, BlushPowder, PeachCloud }

/**
 * One heart's random path, rolled once. Lengths are points (dp on Android),
 * times are seconds.
 */
data class RisingHeart(
  val delay: Double,
  val life: Double,
  /** The glyph's point size at full bloom. */
  val size: Double,
  val tone: HeartTone,
  /** Sideways offset at lift-off, across the button's width. */
  val launch: Double,
  /** Further sideways travel over the rise. */
  val spread: Double,
  val height: Double,
  val swayWidth: Double,
  val phase: Double,
)

/**
 * Where one heart is and how it looks at one moment, relative to the lift-off
 * point (y grows downward, so a rising heart's [y] is negative).
 */
data class RisingHeartPose(
  val x: Double,
  val y: Double,
  /** Radians. */
  val rotation: Double,
  /** The glyph's drawn point size — its full size, smaller while it blooms. */
  val size: Double,
  val opacity: Double,
)

/**
 * The arithmetic behind `RisingHearts`: a gift made visible as hearts lifting
 * off one point and drifting up on slow, swaying paths, then fading. Pure, so
 * the curves can be checked without a frame clock.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/RisingHearts.swift
 * — the same count ladder, the same ranges and the same curves.
 */
object RisingHeartsField {

  /** The cap: the largest gift is still a drift rather than a flood. */
  const val MAX_COUNT = 24

  /**
   * How many hearts a gift of [amount] sends up. Grows with the gift so a
   * hundred feels fuller than one, but on a log scale and capped: 1 → 5,
   * 10 → 18, about 30 and beyond → 24.
   */
  fun count(amount: Int): Int = min(MAX_COUNT, 5 + (4 * log2(max(amount, 1).toDouble())).toInt())

  /**
   * Mostly moon-white, with a blush and a peach heart among them. Repeats are
   * weights.
   */
  private val TONES = listOf(
    HeartTone.MoonCream,
    HeartTone.MoonCream,
    HeartTone.MoonCream,
    HeartTone.MoonCream,
    HeartTone.BlushPowder,
    HeartTone.PeachCloud,
  )

  /** The field for one gift, staggered by index so the hearts leave in turn. */
  fun roll(count: Int, random: Random = Random.Default): List<RisingHeart> =
    (0 until count).map { index ->
      RisingHeart(
        delay = index * 0.07 + random.nextDouble(0.0, 0.12),
        life = random.nextDouble(1.8, 2.5),
        size = random.nextDouble(16.0, 34.0),
        tone = TONES[random.nextInt(TONES.size)],
        launch = random.nextDouble(-70.0, 70.0),
        spread = random.nextDouble(-120.0, 120.0),
        height = random.nextDouble(220.0, 520.0),
        swayWidth = random.nextDouble(8.0, 26.0),
        phase = random.nextDouble(0.0, 1.0),
      )
    }

  /** When the last heart has faded: the field draws nothing from here on. */
  fun duration(hearts: List<RisingHeart>): Double = hearts.maxOfOrNull { it.delay + it.life } ?: 0.0

  /**
   * [heart] at [elapsed] seconds since the field began, or null while it is
   * yet to leave or after it has faded.
   */
  fun pose(heart: RisingHeart, elapsed: Double): RisingHeartPose? {
    val age = elapsed - heart.delay
    if (age < 0 || age > heart.life) return null
    val t = age / heart.life
    val lift = 1 - (1 - t).pow(2.2)
    // The sway grows in over the first quarter, so every heart leaves the
    // button from the same place before the field spreads.
    val sway = sin((t * heart.life * 0.9 + heart.phase) * 2 * PI) * heart.swayWidth * min(1.0, t * 4)
    val opacity = when {
      t < 0.08 -> t / 0.08
      t > 0.5 -> 1 - (t - 0.5) / 0.5
      else -> 1.0
    }
    val bloom = if (t < 0.12) 0.4 + 0.6 * (t / 0.12) else 1.0
    return RisingHeartPose(
      x = heart.launch + heart.spread * lift + sway,
      y = -heart.height * lift,
      rotation = sin(t * 6 + heart.phase * 6) * 0.18,
      size = heart.size * bloom,
      opacity = opacity,
    )
  }
}
